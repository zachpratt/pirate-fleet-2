//
//  Player.swift
//  Pirate Fleet
//
//  Created by Jarrod Parkes on 8/27/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: MoveType

enum MoveType {
    case NormalMove
    case GuaranteedHit
}

// MARK: - Player

class Player {

    // MARK: Properties
    
    var playerDelegate: PlayerDelegate?
    var playerType: PlayerType
    var lastHitPenaltyCell: Cell? = nil
    var numberOfMisses: Int = 0
    var numberOfHits: Int = 0
    
    var performedMoves = Set<GridLocation>()
    var gridViewController: GridViewController
    var gridView: GridView {
        get {
            return gridViewController.gridView
        }
    }
    var grid: [[GridCell]] {
        get {
            return gridViewController.gridView.grid
        }
    }
    var availableMoves = [MoveType]()
    
    // MARK: Initializers
    
    init(frame: CGRect) {
        gridViewController = GridViewController(frame: frame)
        playerType = .Computer
    }

    func reset() {
        gridViewController.reset()
        numberOfMisses = 0
        numberOfHits = 0
        lastHitPenaltyCell = nil
        performedMoves.removeAll(keepCapacity: true)
        availableMoves.append(.NormalMove)
    }
    
    // MARK: Pre-Game Check
    
    func numberOfMines() -> Int {
        return gridViewController.mineCount
    }
    
    func numberOfSeamonsters() -> Int {
        return gridViewController.seamonsterCount
    }
    
    func readyToPlay(checkMines checkMines: Bool = true, checkMonsters: Bool = true) -> Bool {
        let shipsReady = gridViewController.hasRequiredShips()
        
        let minesReady = (checkMines == true) ? gridViewController.hasRequiredMines() : true
        
        let monstersReady = (checkMonsters == true) ? gridViewController.hasRequiredSeamonsters() : true
        
        return shipsReady && minesReady && monstersReady
    }
    
    // MARK: Attacking  
    
    func attackPlayer(player: Player, atLocation: GridLocation) {
        
        performedMoves.insert(atLocation)
        
        // hit a mine?
        if let mine = player.grid[atLocation.x][atLocation.y].mine {
            lastHitPenaltyCell = mine
            numberOfMisses++
            player.gridView.markImageAtLocation(mine.location, image: Settings.Images.MineHit)
        }
        
        // hit a seamonster?
        if let seamonster = player.grid[atLocation.x][atLocation.y].seamonster {
            lastHitPenaltyCell = seamonster
            numberOfMisses++
            player.gridView.markImageAtLocation(seamonster.location, image: Settings.Images.SeaMonsterHit)
        }
        
        // hit a ship?
        if !player.gridViewController.fireCannonAtLocation(atLocation) {
            numberOfMisses++
            player.gridView.markImageAtLocation(atLocation, image: Settings.Images.Miss)
        } else {
            // we hit something!
            numberOfHits++
        }
        
        if let playerDelegate = playerDelegate {
            
            if player.gridViewController.checkSink(atLocation) {
                playerDelegate.playerDidSinkAtLocation(self, location: atLocation)
            }
            
            if player.gridViewController.checkForWin() {
                playerDelegate.playerDidWin(self)
            }
            playerDelegate.playerDidMove(self)
        }
    }
    
    func attackPlayerWithGuaranteedHit(player: Player) {
        var hitShip = false
        
        while hitShip == false {
            let location = RandomGridLocation()
            if !performedMoves.contains(location) {
                // hit a mine?
                if let _ = player.grid[location.x][location.y].mine {
                    continue
                }
                
                // hit a seamonster?
                if let _ = player.grid[location.x][location.y].seamonster {
                    continue
                }
                
                // hit a ship?
                if !player.gridViewController.fireCannonAtLocation(location) {
                    continue
                } else {
                    
                    hitShip = true
                    numberOfHits++
                    performedMoves.insert(location)
                    
                    if let playerDelegate = playerDelegate {
                        
                        if player.gridViewController.checkSink(location) {
                            playerDelegate.playerDidSinkAtLocation(self, location: location)
                        }
                        
                        if player.gridViewController.checkForWin() {
                            playerDelegate.playerDidWin(self)
                        }
                        playerDelegate.playerDidMove(self)
                    }
                }
            }
        }
    }
    
    func attackPlayerWithGuaranteedMine(player: Player) -> Bool {
        var hitMine = false
        
        if player.numberOfMines() == 0 {
            return false
        } else {
            while hitMine == false {
                let location = RandomGridLocation()
                if !performedMoves.contains(location) {
                    // hit a mine?
                    if let mine = player.grid[location.x][location.y].mine {
                        hitMine = true
                        self.lastHitPenaltyCell = mine
                        self.gridViewController.mineCount--
                        player.gridViewController.fireCannonAtLocation(mine.location)
                        
                        performedMoves.insert(mine.location)
                        
                        if let playerDelegate = playerDelegate {
                            if player.gridViewController.checkForWin() {
                                playerDelegate.playerDidWin(self)
                            }
                            playerDelegate.playerDidMove(self)
                        }
                    } else {
                        continue
                    }
                }
            }
            return true
        }
    }
    
    func canAttackPlayer(player: Player, atLocation: GridLocation) -> Bool {
        return locationInBounds(atLocation) && !performedMoves.contains(atLocation)
    }
    
    func locationInBounds(location: GridLocation) -> Bool {
        return !(location.x < 0 || location.y < 0 || location.x >= Settings.DefaultGridSize.width || location.y >= Settings.DefaultGridSize.height)
    }
    
    
    // MARK: Modify Grid
    
    func revealShipAtLocation(location: GridLocation) {
        let connectedCells = grid[location.x][location.y].ship?.cells
        gridView.revealLocations(connectedCells!)
    }
    
    func addPlayerShipsMinesMonsters(numberOfMines: Int = 0, numberOfSeamonsters: Int = 0) {
        
        // randomize ship placement
        for (requiredShipType, requiredNumber) in Settings.RequiredShips {
            for _ in 0..<requiredNumber {
                let shipLength = requiredShipType.rawValue
                
                var shipLocation = RandomGridLocation()
                var vertical = Int(arc4random_uniform(UInt32(2))) == 0 ? true : false
                var ship = Ship(length: shipLength, location: shipLocation, isVertical: vertical, isWooden: false, hitTracker: HitTracker())
                
                while !gridViewController.addShip(ship, playerType: .Computer) {
                    shipLocation = RandomGridLocation()
                    vertical = Int(arc4random_uniform(UInt32(2))) == 0 ? true : false
                    ship = Ship(length: shipLength, location: shipLocation, isVertical: vertical, isWooden: false, hitTracker: HitTracker())
                }
            }
        }
                
        // random mine placement
        for _ in 0..<numberOfMines {
            var location = RandomGridLocation()
            var mine = Mine(location: location)
            while !gridViewController.addMine(mine, playerType: .Computer) {
                location = RandomGridLocation()
                mine = Mine(location: location)
            }
        }
        
        // random seamonster placement
        for _ in 0..<numberOfSeamonsters {
            var location = RandomGridLocation()
            var seaMonster = SeaMonster(location: location)
            while !gridViewController.addSeamonster(seaMonster, playerType: .Computer) {
                location = RandomGridLocation()
                seaMonster = SeaMonster(location: location)
            }
        }
    }
}
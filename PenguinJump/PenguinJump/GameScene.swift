//
//  GameSceneUsingCamera.swift
//  PenguinJump
//
//  Created by Matthew Tso on 5/25/16.
//  Copyright © 2016 De Anza. All rights reserved.
//

import SpriteKit
import CoreData
import AVFoundation

/// The `ColorValues` structure holds RGBA values separately so arithmetic operations can be performed on individual values. Each value is a CGFloat between 0.0 and 1.0
struct ColorValues {
    var red: CGFloat!
    var green: CGFloat!
    var blue: CGFloat!
    var alpha: CGFloat!
}

class GameScene: SKScene, IcebergGeneratorDelegate {
    
    // Framework Objects
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    let fetchRequest = NSFetchRequest(entityName: "GameData")
    var gameData : GameData!
    
    // Game options
    var enableScreenShake = true
    
    // Node Objects
    var cam:SKCameraNode!
    var penguin: Penguin!
    var stage: IcebergGenerator!
    let jumpAir = SKShapeNode(circleOfRadius: 20.0)
    var waves: Waves!
    var background: Background!
    var coinLayer: SKNode?
    var lightningLayer: SKNode?
    var sharkLayer: SKNode?
    
    // Audio
    
    var backgroundMusic: AVAudioPlayer?
    var backgroundOcean: AVAudioPlayer?
    
    var splashSound: AVAudioPlayer?
    var jumpSound: AVAudioPlayer?
    var landingSound: AVAudioPlayer?
    var buttonPressSound: AVAudioPlayer?
    var coinSound: AVAudioPlayer?
    
    var alertSound: AVAudioPlayer?
    var sharkSound: AVAudioPlayer?
    var lurkingSound: AVAudioPlayer?
    var zapSound: AVAudioPlayer?
    var thunderSound: AVAudioPlayer?
    var powerUpSound: AVAudioPlayer?
    var burstSound: AVAudioPlayer?
    
    var musicInitialized = false
    
    // Labels
    var startMenu : StartMenuNode!
    
    // Game session logic
    var gameBegin = false
    var gameRunning = false
    var gameOver = false
    var gamePaused = false
    var shouldCorrectAfterPause = false
    var playerTouched = false
    var freezeCamera = false
    /// Difficulty modifier that ranges from `0.0` to `1.0`.
    var difficulty = 0.0

    var previousTime: NSTimeInterval?
    var timeSinceLastUpdate: NSTimeInterval = 0.0
    var stormTimeElapsed: NSTimeInterval = 0.0
    var stormIntensity = 0.0
    var stormDuration = 15.0
    var stormTransitionDuration = 2.0
    var stormMode = false
    let bgColorValues = ColorValues(red: 0/255, green: 151/255, blue: 255/255, alpha: 1)
    var windSpeed = 0.0
    var windEnabled = true
    var windDirectionRight = true
    
    // Information bar
    var intScore = 0
    var scoreLabel: SKLabelNode!
    var coinLabel: SKLabelNode!
    var chargeBar: ChargeBar!
    var shouldFlash = false
    let pauseButton = SKLabelNode(text: "I I")
    
    var totalCoins = 0
    
    // Audio settings -> fetched from CoreData?
    var musicVolume:Float = 1.0
    var soundVolume:Float = 1.0
    
    // Debug
    var testZoomed = false
    var viewOutlineOn = false
    var viewFrame: SKShapeNode!
    
    let debugButton = SKLabelNode(text: "DEBUG")
    let zoomButton = SKLabelNode(text: "ZOOM")
    let rainButton = SKLabelNode(text: "RAINDROP")
    let lightningButton = SKLabelNode(text: "LIGHTNING")
    let sharkButton = SKLabelNode(text: "SHARK")
    let stormButton = SKLabelNode(text: "STORM")
    let moneyButton = SKLabelNode(text: "MONEY")
    let viewOutlineButton = SKLabelNode(text: "OUTLINE VIEW")
    
    // MARK: - Scene setup
    
    override func didMoveToView(view: SKView) {
        // Set up audio files
        if musicInitialized == false {
            musicInitialized = true
            if let backgroundMusic = audioPlayerWithFile("Reformat", type: "mp3") {
                self.backgroundMusic = backgroundMusic
            }
        }
        if let backgroundOcean = audioPlayerWithFile("ocean", type: "m4a") {
            self.backgroundOcean = backgroundOcean
        }
        if let splashSound = audioPlayerWithFile("splash", type: "m4a") {
            self.splashSound = splashSound
        }
        if let jumpSound = audioPlayerWithFile("jump", type: "m4a") {
            self.jumpSound = jumpSound
        }
        if let landingSound = audioPlayerWithFile("landing", type: "m4a") {
            self.landingSound = landingSound
        }
        if let buttonPressSound = audioPlayerWithFile("button_press", type: "m4a") {
            self.buttonPressSound = buttonPressSound
        }
        if let coinSound = audioPlayerWithFile("coin", type: "wav") {
            self.coinSound = coinSound
        }
        if let alertSound = audioPlayerWithFile("alert", type: "mp3") {
            self.alertSound = alertSound
        }
        if let sharkSound = audioPlayerWithFile("roar", type: "wav") {
            self.sharkSound = sharkSound
        }
        if let lurkingSound = audioPlayerWithFile("lurking", type: "mp3") {
            lurkingSound.numberOfLoops = -1
            self.lurkingSound = lurkingSound
        }
        if let zapSound = audioPlayerWithFile("zap", type: "mp3") {
            self.zapSound = zapSound
        }
        if let thunderSound = audioPlayerWithFile("thunder", type: "wav") {
            self.thunderSound = thunderSound
        }
        if let powerUpSound = audioPlayerWithFile("power_up", type: "mp3") {
            self.powerUpSound = powerUpSound
        }
        if let burstSound = audioPlayerWithFile("balloon_pop", type: "mp3") {
            self.burstSound = burstSound
        }
        
        
        // Fetch total coins data and sound settings
        var fetchedData = [GameData]()
        do {
            fetchedData = try managedObjectContext.executeFetchRequest(fetchRequest) as! [GameData]
        } catch {
            print(error)
        }
        if fetchedData.first != nil {
            gameData = fetchedData.first
        }
      
        // Physics setup
        // TODO: set up physics world
        setupPhysics()
        
        // Set up Game Scene
        setupScene()
        
        // Start Menu Setup
        startMenu = StartMenuNode(frame: view.frame)
        startMenu.userInteractionEnabled = true //change to true once menu interaction properly enabled
        cam.addChild(startMenu)
        
        // Camera Setup
        cam.position = penguin.position
        cam.position.y += view.frame.height * 0.06
        let zoomedIn = SKAction.scaleTo(0.4, duration: 0.0)
        cam.runAction(zoomedIn)
        
        let startX = penguin.position.x
        let startY = penguin.position.y
        let pan = SKAction.moveTo(CGPoint(x: startX, y: startY), duration: 0.0)
        pan.timingMode = .EaseInEaseOut
        cam.runAction(pan)
        
        
        // Debug buttons
        debugButton.name = "debugButton"
        debugButton.fontName = "Helvetica Neue Condensed Black"
        debugButton.fontSize = 24
        debugButton.alpha = 0.5
        debugButton.zPosition = 2000000
        debugButton.fontColor = UIColor.blackColor()
        debugButton.position = CGPoint(x: 0 /* -view.frame.width / 2 */, y: view.frame.height / 2)
        debugButton.position.y -= debugButton.frame.height * 2
        cam.addChild(debugButton)
        
        zoomButton.name = "testZoom"
        zoomButton.fontName = "Helvetica Neue Condensed Black"
        zoomButton.fontSize = 24
        zoomButton.alpha = 0.5
        zoomButton.zPosition = 2000000
        zoomButton.fontColor = UIColor.blackColor()
        zoomButton.position = CGPoint(x: 0 /* -view.frame.width / 2 */, y: view.frame.height / 2 - debugButton.frame.height * 2)
        cam.addChild(zoomButton)

        rainButton.name = "rainButton"
        rainButton.fontName = "Helvetica Neue Condensed Black"
        rainButton.fontSize = 24
        rainButton.alpha = 0.5
        rainButton.zPosition = 2000000
        rainButton.fontColor = UIColor.blackColor()
        rainButton.position = CGPoint(x: 0, y: view.frame.height / 2 - debugButton.frame.height * 3)
        cam.addChild(rainButton)
        
        lightningButton.name = "lightningButton"
        lightningButton.fontName = "Helvetica Neue Condensed Black"
        lightningButton.fontSize = 24
        lightningButton.alpha = 0.5
        lightningButton.zPosition = 2000000
        lightningButton.fontColor = UIColor.blackColor()
        lightningButton.position = CGPoint(x: 0, y: view.frame.height / 2 - debugButton.frame.height * 4)
        cam.addChild(lightningButton)
        
        sharkButton.name = "sharkButton"
        sharkButton.fontName = "Helvetica Neue Condensed Black"
        sharkButton.fontSize = 24
        sharkButton.alpha = 0.5
        sharkButton.zPosition = 2000000
        sharkButton.fontColor = UIColor.blackColor()
        sharkButton.position = CGPoint(x: 0, y: view.frame.height / 2 - debugButton.frame.height * 5)
        cam.addChild(sharkButton)
        
        stormButton.name = "stormButton"
        stormButton.fontName = "Helvetica Neue Condensed Black"
        stormButton.fontSize = 24
        stormButton.alpha = 0.5
        stormButton.zPosition = 2000000
        stormButton.fontColor = UIColor.blackColor()
        stormButton.position = CGPoint(x: 0, y: view.frame.height / 2 - debugButton.frame.height * 6)
        cam.addChild(stormButton)
        
        moneyButton.name = "moneyButton"
        moneyButton.fontName = "Helvetica Neue Condensed Black"
        moneyButton.fontSize = 24
        moneyButton.alpha = 0.5
        moneyButton.zPosition = 2000000
        moneyButton.fontColor = UIColor.blackColor()
        moneyButton.position = CGPoint(x: 0, y: view.frame.height / 2 - debugButton.frame.height * 7)
        cam.addChild(moneyButton)
        
        viewOutlineButton.name = "viewOutlineButton"
        viewOutlineButton.fontName = "Helvetica Neue Condensed Black"
        viewOutlineButton.fontSize = 24
        viewOutlineButton.alpha = 0.5
        viewOutlineButton.zPosition = 2000000
        viewOutlineButton.fontColor = UIColor.blackColor()
        viewOutlineButton.position = CGPoint(x: 0, y: view.frame.height / 2 - debugButton.frame.height * 8)
        cam.addChild(viewOutlineButton)
        
        zoomButton.hidden = true
        rainButton.hidden = true
        lightningButton.hidden = true
        sharkButton.hidden = true
        stormButton.hidden = true
        moneyButton.hidden = true
        viewOutlineButton.hidden = true
        
        pauseButton.name = "pauseButton"
        pauseButton.fontName = "Helvetica Neue Condensed Black"
        pauseButton.fontSize = 24
        pauseButton.zPosition = 200000
        pauseButton.fontColor = UIColor.blackColor()
        pauseButton.position = CGPoint(x: view.frame.width * 0.5, y: view.frame.height * 0.47)
        pauseButton.position.x -= pauseButton.frame.width * 1.5
        pauseButton.position.y -= pauseButton.frame.height * 2
        pauseButton.alpha = 0
        cam.addChild(pauseButton)
        
        viewFrame = SKShapeNode(rectOfSize: view.frame.size)
        viewFrame.position = cam.position
        viewFrame.strokeColor = SKColor.redColor()
        viewFrame.fillColor = SKColor.clearColor()
        viewFrame.hidden = viewOutlineOn ? false : true
        addChild(viewFrame)
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enterPause", name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "becomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    func setupScene() {
        
        gameOver = false
        
        cam = SKCameraNode()
        cam.position = CGPoint(x: CGRectGetMidX(frame), y: CGRectGetMidY(frame))
        camera = cam
        addChild(cam)        
        
        stage = IcebergGenerator(view: view!, camera: cam)
        stage.position = view!.center
        stage.zPosition = 10
        stage.delegate = self
        addChild(stage)
        
        coinLayer = SKNode()
        coinLayer?.position = view!.center
        coinLayer?.zPosition = 500 // above stage
        addChild(coinLayer!)
        
        lightningLayer = SKNode()
        lightningLayer?.position = view!.center
        lightningLayer?.zPosition = 500 // same level as coins (for shadow)
        addChild(lightningLayer!)
        
        sharkLayer = SKNode()
        sharkLayer?.position = view!.center
        sharkLayer?.zPosition = 0
        addChild(sharkLayer!)
        
//        backgroundColor = SKColor(red: 0/255, green: 151/255, blue: 255/255, alpha: 1.0)
        backgroundColor = SKColor(red: bgColorValues.red, green: bgColorValues.green, blue: bgColorValues.blue, alpha: bgColorValues.alpha)
        
        scoreLabel = SKLabelNode(text: "Score: " + String(intScore))
        scoreLabel.fontName = "Helvetica Neue Condensed Black"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = SKColor.blackColor()
        scoreLabel.position = CGPoint(x: -view!.frame.width * 0.45, y: view!.frame.height * 0.45)
        scoreLabel.zPosition = 30000
        scoreLabel.horizontalAlignmentMode = .Left
        
        chargeBar = ChargeBar(size: scoreLabel.frame.size)
        chargeBar.position = CGPoint(x: 0 /* - scoreLabel.frame.width / 2 */, y: 0 - scoreLabel.frame.height * 0.5)
        
        scoreLabel.addChild(chargeBar)
//        chargeBar.position.x -= scoreLabel.frame.width / 2
        
//        chargeBar.position = CGPoint(x: scoreLabel.position.x - scoreLabel.frame.width / 2, y: scoreLabel.position.y - scoreLabel.frame.height)
        
        coinLabel = SKLabelNode(text: "\(totalCoins) coins")
        coinLabel.fontName = "Helvetica Neue Condensed Black"
        coinLabel.fontSize = 24
        coinLabel.fontColor = SKColor.blackColor()
        coinLabel.position = CGPoint(x: view!.frame.width * 0.45, y: view!.frame.height * 0.45)
        coinLabel.zPosition = 30000
        coinLabel.horizontalAlignmentMode = .Right
        cam.addChild(coinLabel)
        
        
        // Fetch penguin type
        var fetchedData = [GameData]()
        var penguinType: PenguinType!
        do {
            fetchedData = try managedObjectContext.executeFetchRequest(fetchRequest) as! [GameData]
                
            do {
                fetchedData = try managedObjectContext.executeFetchRequest(fetchRequest) as! [GameData]
            } catch { print(error) }
            
        } catch {
            print(error)
        }
        
        if let gameData = fetchedData.first {
            switch (gameData.selectedPenguin as String) {
            case "normal":
                penguinType = .normal
            case "parasol":
                penguinType = .parasol
            case "tinfoil":
                penguinType = .tinfoil
            case "shark":
                penguinType = .shark
            case "penguinAngel":
                penguinType = .penguinAngel
            case "penguinCrown":
                penguinType = .penguinCrown
            case "penguinDuckyTube":
                penguinType = .penguinDuckyTube
            case "penguinMarathon":
                penguinType = .penguinMarathon
            case "penguinMohawk":
                penguinType = .penguinMohawk
            case "penguinPolarBear":
                penguinType = .penguinPolarBear
            case "penguinPropellerHat":
                penguinType = .penguinPropellerHat
            case "penguinSuperman":
                penguinType = .penguinSuperman
            case "penguinTophat":
                penguinType = .penguinTophat
            case "penguinViking":
                penguinType = .penguinViking
            default:
                penguinType = .normal
            }
            totalCoins = gameData.totalCoins as Int
            coinLabel.text = "\(totalCoins) coins"
        }
        
        // Wrap penguin around a cropnode for death animation
        let penguinPositionInScene = CGPoint(x: size.width * 0.5, y: size.height * 0.3)
        
        penguin = Penguin(type: penguinType)

        penguin.position = penguinPositionInScene
        penguin.zPosition = 2100
        penguin.userInteractionEnabled = true
        addChild(penguin)
        
        stage.newGame(convertPoint(penguinPositionInScene, toNode: stage))
        
        waves = Waves(camera: cam, gameScene: self)
        waves.position = view!.center
        waves.zPosition = 0
        addChild(waves)
//        bob(waves)
        waves.stormMode = self.stormMode
        waves.bob()
        
        background = Background(view: view!, camera: cam)
        background.position = view!.center
        background.zPosition = -1000
        addChild(background)
        
        playMusic()
    }
    
    // MARK: - Scene Controls
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        for touch in touches {
            let positionInScene = touch.locationInNode(self)
            let touchedNodes = self.nodesAtPoint(positionInScene)
            for touchedNode in touchedNodes {
                if let name = touchedNode.name
                {
                    if name == "debugButton" {
                        debugButton.hidden = true
                        zoomButton.hidden = false
                        rainButton.hidden = false
                        lightningButton.hidden = false
                        sharkButton.hidden = false
                        stormButton.hidden = false
                        moneyButton.hidden = false
                        viewOutlineButton.hidden = false
                    } else {
                        debugButton.hidden = false
                        zoomButton.hidden = true
                        rainButton.hidden = true
                        lightningButton.hidden = true
                        sharkButton.hidden = true
                        stormButton.hidden = true
                        moneyButton.hidden = true
                        viewOutlineButton.hidden = true
                    
                    
                        if name == "testZoom" {
                            let zoomOut = SKAction.scaleTo(3.0, duration: 0.5)
                            let zoomIn = SKAction.scaleTo(1.0, duration: 0.5)
                            
                            testZoomed ? cam.runAction(zoomIn) : cam.runAction(zoomOut)
                            testZoomed = testZoomed ? false : true
                        } else if name == "rainButton" {
                            let raindrop = Raindrop()
                            raindrop.zPosition = 100000
                            raindrop.drop(view!.center, windSpeed: windSpeed)
                            addChild(raindrop)
                        } else if name == "lightningButton" {
                            if let berg = (stage as IcebergGenerator).highestBerg {
                                let lightningRandomX = CGFloat(random()) % berg.size.width - berg.size.width / 2
                                let lightningRandomY = CGFloat(random()) % berg.size.height - berg.size.height / 2
                                let lightningPosition = CGPoint(x: berg.position.x + lightningRandomX, y: berg.position.y + lightningRandomY)
                                let lightning = Lightning(view: view!)
                                lightning.position = lightningPosition
                                lightningLayer?.addChild(lightning)
                            }
                        } else if name == "sharkButton" {
                            if let berg = (stage as IcebergGenerator).highestBerg {
                                let sharkX = berg.position.x
                                let sharkY = berg.position.y + (350 / 4)
                                let sharkPosition = CGPoint(x: sharkX, y: sharkY)
                                
                                let shark = Shark()
                                shark.position = sharkPosition
                                sharkLayer?.addChild(shark)
                                shark.beginSwimming()
                            }
                        } else if name == "stormButton" {
                            beginStorm()
                        } else if name == "moneyButton" {
                            for _ in 1...1000 {
                                incrementTotalCoins()
                            }
                        } else if name == "viewOutlineButton" {
                            viewOutlineOn = !viewOutlineOn
                        } else if name == "pauseButton" {
                            enterPause()
                        } else if touchedNode.name == "pauseCover" {
                            exitPause()
                        } else if penguin.inAir && !penguin.doubleJumped {
                            // IF A BUTTON WASN'T TOUCHED, IT'S A DOUBLE JUMP COMMAND
                            // http://stackoverflow.com/questions/26551777/sprite-kit-determine-vector-of-swipe-gesture-to-flick-sprite
                            // use above for swipe double jump
                            
                            penguin.doubleJumped = true
                            
                            let delta = positionInScene - penguin.position
                            
                            let jumpAir = SKShapeNode(circleOfRadius: 20.0)
                            jumpAir.fillColor = SKColor.clearColor()
                            jumpAir.strokeColor = SKColor.whiteColor()
                            
                            jumpAir.xScale = 1.0
                            jumpAir.yScale = 1.0
                            
                            jumpAir.position = penguin.position
                            addChild(jumpAir)
                            
                            let airExpand = SKAction.scaleBy(2.0, duration: 0.4)
                            let airFade = SKAction.fadeAlphaTo(0.0, duration: 0.4)
                            
                            airExpand.timingMode = .EaseOut
                            airFade.timingMode = .EaseIn
                            
                            jumpAir.runAction(airExpand)
                            jumpAir.runAction(airFade, completion: {
                                self.jumpAir.removeFromParent()
                            })
                            
                            doubleJump(CGVector(dx: -delta.x * 2.5, dy: -delta.y * 2.5))
                        }
                    }
                }

            }
        }
    }
    
    func doubleJump(velocity: CGVector) {
        let nudgeRate: CGFloat = 180
        let nudgeDistance = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let nudgeDuration = Double(nudgeDistance / nudgeRate)
        
        let nudge = SKAction.moveBy(velocity, duration: nudgeDuration)
        penguin.runAction(nudge)
        jumpSound?.currentTime = 0
        if gameData.soundEffectsOn == true { jumpSound?.play() }
    }
    
    // MARK: - Pause state
    
    func becomeActive() {
        if gamePaused {
            enterPause()
        }
    }
    
    func enterPause() {
        print("enterPause")
        if gameRunning {
            shouldCorrectAfterPause = true
            gamePaused = true
            penguin.userInteractionEnabled = false
            paused = true
            
            var needsPauseCover = true
            for child in children {
                if child.name == "pauseCover" {
                    needsPauseCover = false
                }
            }
            
            if needsPauseCover {
                let cover = SKSpriteNode(color: SKColor.blackColor(), size: view!.frame.size)
                cover.name = "pauseCover"
                cover.position = cam.position
                cover.alpha = 0.5
                cover.zPosition = 1000000
                addChild(cover)
                
                let unPause = SKLabelNode(text: "Tap to Play")
                unPause.name = "pauseCover"
                unPause.position = cam.position
                unPause.fontColor = SKColor.whiteColor()
                unPause.fontName = "Helvetica Neue Condensed Black"
                unPause.zPosition = 1000001
                addChild(unPause)
            }
        }
    }
    
    func exitPause() {
        for child in children {
            if child.name == "pauseCover" {
                child.removeFromParent()
            }
        }
        gamePaused = false
        penguin.userInteractionEnabled = true
        paused = false
    }
    
    // MARK: - Game state
    
    func beginGame() {
        penguin.beginGame()
        
        let zoomOut = SKAction.scaleTo(1.0, duration: 2.0)
        
        let cameraFinalDestX = penguin.position.x
        let cameraFinalDestY = penguin.position.y + frame.height / 6
        
        let pan = SKAction.moveTo(CGPoint(x: cameraFinalDestX, y: cameraFinalDestY), duration: 2.0)
        pan.timingMode = .EaseInEaseOut
        zoomOut.timingMode = .EaseInEaseOut
        
        cam.runAction(zoomOut)
        cam.runAction(pan, completion: {
            self.cam.addChild(self.scoreLabel)
            
            self.scoreLabel.position.y += 300
            
            let scoreLabelDown = SKAction.moveBy(CGVector(dx: 0, dy: -300), duration: 1.0)
            scoreLabelDown.timingMode = .EaseOut
            self.scoreLabel.runAction(scoreLabelDown)
            
            self.pauseButton.alpha = 1
            
            self.gameBegin = true
            self.gameRunning = true
        })
        
        let playButtonDown = SKAction.moveBy(CGVector(dx: 0, dy: -300), duration: 1.0)
        playButtonDown.timingMode = .EaseIn
        startMenu.playButton.runAction(playButtonDown, completion: {
            self.startMenu.playButton.removeFromParent()
        })
        
        let titleUp = SKAction.moveBy(CGVector(dx: 0, dy: 400), duration: 1.0)
        titleUp.timingMode = .EaseIn
        startMenu.title.runAction(titleUp, completion: {
            self.startMenu.title.removeFromParent()
        })

    }
    
    func restart() {
        removeAllChildren()
        removeAllActions()
        cam.removeAllChildren()
        
        penguin.removeAllActions()
        
        setupScene()
        freezeCamera = false

        intScore = 0
        cam.addChild(scoreLabel)
        gameRunning = true

    }
    
    func runGameOver() {
        if gameOver {
            for child in stage.children {
                let berg = child as! Iceberg
                berg.removeAllActions()
            }
            gameRunning = false
            freezeCamera = true
            self.backgroundColor = SKColor(red: 0/255, green: 120/255, blue: 200/255, alpha: 1.0)
            
            penguin.shadow.removeFromParent()
            
            let fall = SKAction.moveBy(CGVector(dx: 0, dy: -20), duration: 0.2)
            fall.timingMode = .EaseOut
            let slideUp = SKAction.moveBy(CGVector(dx: 0, dy: 25), duration: 0.2)
            slideUp.timingMode = .EaseOut
            
            penguin.runAction(slideUp)
            penguin.body.runAction(fall)
            
            if gameData.soundEffectsOn == true { splashSound?.play() }
            
            if gameData != nil {
                let highScore = gameData.highScore as Int
                
                if intScore > highScore {
                    gameData.highScore = intScore
                    
                    do { try managedObjectContext.save() } catch { print(error) }
                }
            }
            
            lurkingSound?.stop()
            fadeMusic()
            
            let wait = SKAction.waitForDuration(2.0)
            self.runAction(wait, completion:  {
                let scoreScene = ScoreScene(size: self.size)
                scoreScene.score = self.intScore
                
                let transition = SKTransition.moveInWithDirection(.Up, duration: 0.5)
                scoreScene.scaleMode = SKSceneScaleMode.AspectFill
                self.scene!.view?.presentScene(scoreScene, transition: transition)
            })
        }
    }
    
    func initializeGameData() {
        let newGameData = NSEntityDescription.insertNewObjectForEntityForName("GameData", inManagedObjectContext: managedObjectContext) as! GameData
        newGameData.highScore = 0
        newGameData.totalCoins = 0
        newGameData.selectedPenguin = "normal"
        newGameData.musicOn = true
        newGameData.soundEffectsOn = true
        newGameData.musicPlaying = false
        
        do {
            try managedObjectContext.save()
        } catch { print(error) }
    }

    func playMusic() {
        if gameData.musicOn == true && gameData.musicPlaying == false {
            if let backgroundMusic = backgroundMusic {
                backgroundMusic.volume = 0.0
                backgroundMusic.numberOfLoops = -1 // Negative integer to loop indefinitely
                backgroundMusic.play()
                fadeAudioPlayer(backgroundMusic, fadeTo: musicVolume * 0.5, duration: 1, completion: nil)
            }
            if let backgroundOcean = backgroundOcean {
                backgroundOcean.volume = 0.0
                backgroundOcean.numberOfLoops = -1 // Negative integer to loop indefinitely
                backgroundOcean.play()
                fadeAudioPlayer(backgroundOcean, fadeTo: musicVolume * 0.1, duration: 1, completion: nil)
            }
            gameData.musicPlaying = true
            do { try managedObjectContext.save() } catch { print(error) }
        }
    }
    
    func fadeMusic() {
        if gameData.musicOn == true {
            fadeAudioPlayer(backgroundMusic!, fadeTo: 0.0, duration: 1.0, completion: {() in
                self.backgroundMusic?.stop()
            })
            fadeAudioPlayer(backgroundOcean!, fadeTo: 0.0, duration: 1.0, completion: {() in
                self.backgroundOcean?.stop()
            })
            gameData.musicOn = false
            gameData.musicPlaying = false
            do { try managedObjectContext.save() } catch { print(error) }
        }
    }
    
    // MARK: - Iceberg Generator Delegate method
    
    func didGenerateIceberg(generatedIceberg: Iceberg) {
        let berg = generatedIceberg
        
        let coinRandomX = CGFloat(random()) % berg.size.width - berg.size.width / 2
        let coinRandomY = CGFloat(random()) % berg.size.height - berg.size.height / 2
        let coinPosition = CGPoint(x: berg.position.x + coinRandomX, y: berg.position.y + coinRandomY)
        
        let coinRandom = random() % 3
        if coinRandom == 0 {
            let coin = Coin()
            coin.position = coinPosition
            coinLayer?.addChild(coin)
        }
        
        let lightningRandomX = CGFloat(random()) % berg.size.width - berg.size.width / 2
        let lightningRandomY = CGFloat(random()) % berg.size.height - berg.size.height / 2
        let lightningPosition = CGPoint(x: berg.position.x + lightningRandomX, y: berg.position.y + lightningRandomY)
        
        let stormIntensityInverseModifier = (2 * stormIntensity + 1)
        let lightningProbability = (-95 * difficulty + 100)
        let lightningRandom: Int = random() % Int(lightningProbability / stormIntensityInverseModifier)
        if lightningRandom == 0 {
            let lightning = Lightning(view: view!)
            lightning.position = lightningPosition
            lightningLayer?.addChild(lightning)
        }
        
        if generatedIceberg.name != "rightBerg" && generatedIceberg.name != "leftBerg" {
            // Can put in a shark
            
            // Reusing lightning RNG for test
            if lightningRandom == 1 {
                let sharkX = berg.position.x
                let sharkY = berg.position.y + (350 / 4)
                let sharkPosition = CGPoint(x: sharkX, y: sharkY)
                
                let shark = Shark()
                shark.position = sharkPosition
                sharkLayer?.addChild(shark)
                shark.beginSwimming()
            }
        }
    }
    
    // MARK: - Updates
    
    override func update(currentTime: NSTimeInterval) {
        if shouldCorrectAfterPause {
            timeSinceLastUpdate = 0.0
            shouldCorrectAfterPause = false
            previousTime = currentTime
        } else {
            if let previousTime = previousTime {
                timeSinceLastUpdate = currentTime - previousTime
                self.previousTime = currentTime
            } else {
                self.previousTime = currentTime
            }
        }
        
        stage.update()
        waves.update()
        coinLabel.text = "\(totalCoins) coins"

        if gameRunning {
            penguin.userInteractionEnabled = true

            scoreLabel.text = "Score: " + String(intScore)
            
            penguinUpdate()
            coinUpdate()
            chargeBarUpdate()
            trackDifficulty()
            
            checkGameOver()
            if gameOver {
                runGameOver()
            }
            
            updateStorm()
            updateRain()
            updateLightning()
            updateShark()
            
            centerCamera()
        } else {
            penguin.userInteractionEnabled = false
            penguin.removeAllActions()
            for child in penguin.children {
                child.removeAllActions()
            }
        }
        
    }
    
    func updateShark() {
        if let sharkLayer = sharkLayer {
            for child in sharkLayer.children {
                let shark = child as! Shark
                
                if penguin.shadow.intersectsNode(shark.wave) {
                    if !shark.didBeginKill {
                        shark.didBeginKill = true
                        
                        penguin.removeAllActions()
                        
                        shark.kill(penguinMove: {
                            let deathMove = SKAction.moveTo(shark.position, duration: 0.5)
                            self.penguin.runAction(deathMove)
                        })
                    }
                }
                
                if shark.position.y < cam.position.y - view!.frame.height * 1.2 {
                    shark.removeFromParent()
                    
                    if sharkLayer.children.count < 1 {
                        lurkingSound?.stop()
                    }
                }
            }
        }
    }
    
    func updateLightning() {
        if let lightningLayer = lightningLayer{
            for child in lightningLayer.children {
                let lightning = child as! Lightning
                
                let difference = lightning.position.y - penguin.position.y
                if difference < 40 {
                    if !lightning.didBeginStriking {
                        lightning.didBeginStriking = true
                        lightning.beginStrike()
                    }
                }
            }
        }
    }
    
    func updateRain() {
        if stormMode {
            let maxRaindropsPerSecond = 80.0

            // Storm start ease in
            var raindropsPerSecond = 0.1 * pow(5.3, stormTimeElapsed) - 0.1
            
            // Cap at 80 maximum
            if raindropsPerSecond > maxRaindropsPerSecond {
                raindropsPerSecond = maxRaindropsPerSecond
            }
            
            // Storm ending rain ease out
            if stormTimeElapsed > stormDuration - 2 {
                raindropsPerSecond = 0.1 * pow(5.3, abs(stormTimeElapsed - stormDuration)) - 0.1
            }
            
            let numberOfRainDrops = Int(timeSinceLastUpdate * raindropsPerSecond /* * stormIntensity */) + 1// + randomRaindrops
            
            for _ in 0..<numberOfRainDrops {
                
                let randomX = 3.0 * CGFloat(random()) % view!.frame.width - view!.frame.width / 2
                let randomY = 2.0 * CGFloat(random()) % view!.frame.height - view!.frame.height / 4

                let raindrop = Raindrop()
                addChild(raindrop)

                raindrop.drop(CGPoint(x: penguin.position.x + CGFloat(randomX), y: penguin.position.y + CGFloat(randomY)), windSpeed: windSpeed * 2)
                
                // Attempt to avoid dropping a raindrop over an iceberg.
                for child in stage.children {
                    let berg = child as! Iceberg
                    if berg.containsPoint(convertPoint(CGPoint(x: penguin.position.x + CGFloat(randomX), y: penguin.position.y + CGFloat(randomY)), toNode: stage)) {
                        raindrop.zPosition = 0
                        
                    } else {
                        raindrop.zPosition = 24000
                    }
                }
            }
        }
    }
    
    func updateWinds() {
        if windEnabled {
            windSpeed = windDirectionRight ? stormIntensity * 70 : -stormIntensity * 70
            
            var deltaX = penguin.inAir ? windSpeed * timeSinceLastUpdate * difficulty : windSpeed * 0.5 * timeSinceLastUpdate * difficulty
            
            if penguin.type == PenguinType.shark {
                deltaX = deltaX * 0.75
            }
            
            let push = SKAction.moveBy(CGVector(dx: deltaX, dy: 0), duration: timeSinceLastUpdate)
            penguin.runAction(push)
        }

    }
    
    func updateStorm() {

        if stormMode {
            updateWinds()
            
            if stormTimeElapsed < stormDuration - stormTransitionDuration {
                stormTimeElapsed += timeSinceLastUpdate
                
                if stormIntensity < 0.99 {
                    stormIntensity += 1.0 * (timeSinceLastUpdate / stormTransitionDuration) * 0.3
                } else {
                    stormIntensity = 1.0
                    
                }
                
            } else {
                if stormIntensity > 0.01 {
                    stormIntensity -= 1.0 * (timeSinceLastUpdate / stormTransitionDuration) * 0.3
                } else {
                    stormIntensity = 0.0
                    
                    // End storm mode.
                    stormTimeElapsed = 0.0
                    stormMode = false
                    
                    waves.stormMode = self.stormMode
                    waves.bob()
                    
                    for child in stage.children {
                        let berg = child as! Iceberg
                        berg.stormMode = self.stormMode
                        berg.bob()
                    }
                    
                    chargeBar.barFlash.removeAllActions()

                }
            }
            
        } else {

        }
        backgroundColor = SKColor(red: bgColorValues.red, green: bgColorValues.green - CGFloat(40 / 255 * stormIntensity), blue: bgColorValues.blue - CGFloat(120 / 255 * stormIntensity), alpha: bgColorValues.alpha)
    }
    
    func penguinUpdate() {
        for child in stage.children {
            let berg = child as! Iceberg
            
            if penguin.shadow.intersectsNode(berg) && !berg.landed && !penguin.inAir && berg.name != "firstBerg" {
                // Penguin landed on an iceberg if check is true
                if gameData.soundEffectsOn == true { landingSound?.play() }
                
                berg.land()
                stage.updateCurrentBerg(berg)
                shakeScreen()
                
                let sinkDuration = 7.0 - (3.0 * difficulty)
                berg.sink(sinkDuration, completion: nil)
                penguin.land(sinkDuration)
                
                intScore += 1
                
                let scoreBumpUp = SKAction.scaleTo(1.2, duration: 0.1)
                let scoreBumpDown = SKAction.scaleTo(1.0, duration: 0.1)
                scoreLabel.runAction(SKAction.sequence([scoreBumpUp, scoreBumpDown]))
                
            } else if penguin.shadow.intersectsNode(berg) && !penguin.inAir {
                // Penguin landed on an iceberg that is sinking.
                // Needs fix. Constantly bumps right now.
//                berg.bump()
            }
        }
        
        if !penguin.hitByLightning {
            if let lightningLayer = lightningLayer {
                for child in lightningLayer.children {
                    let lightning = child as! Lightning
                    
                    if lightning.activated {
                        if lightning.shadow.intersectsNode(penguin.shadow) {
                            // Penguin hit!

                            penguin.hitByLightning = true
                            
                            let lightningShadowPositionInScene = convertPoint(lightning.shadow.position, fromNode: lightning)
                            let penguinShadowPositionInScene = convertPoint(penguin.shadow.position, fromNode: penguin)
                            
                            let maxPushDistance = penguin.size.height * 2
                            
                            let deltaX = penguinShadowPositionInScene.x - lightningShadowPositionInScene.x
                            let deltaY = penguinShadowPositionInScene.y - lightningShadowPositionInScene.y
                            
                            let distanceFromLightningCenter = sqrt(deltaX * deltaX + deltaY * deltaY)
                            let pushDistance = -distanceFromLightningCenter + maxPushDistance
                            
                            let angle = atan(deltaY / deltaX)
                            
                            let pushX = cos(angle) * pushDistance
                            let pushY = sin(angle) * pushDistance
                            
                            print(CGVector(dx: pushX, dy: pushY))
                            let push = SKAction.moveBy(CGVector(dx: pushX, dy: pushY), duration: 1.0)
                            push.timingMode = .EaseOut
                            penguin.removeAllActions()
                            penguin.runAction(push, completion:  {
                                self.penguin.hitByLightning = false
                            })
                        }
                    }
                }
            }
        }
        
        
    }
    
    func chargeBarUpdate() {
        chargeBar.mask.size.width = scoreLabel.frame.width * 0.95
        
        if chargeBar.bar.position.x >= chargeBar.mask.size.width {
            shouldFlash = true
            
            if shouldFlash && !stormMode {
                shouldFlash = false
                beginStorm()
                
                chargeBar.flash(completion: {
                    
                    let chargeDown = SKAction.moveToX(0, duration: self.stormDuration - self.stormTimeElapsed)
                    self.chargeBar.bar.runAction(chargeDown)
                })
                
                
            }
        } else if chargeBar.bar.position.x > 0 && !stormMode {
            let decrease = SKAction.moveBy(CGVector(dx: -5 * timeSinceLastUpdate, dy: 0), duration: timeSinceLastUpdate)
            chargeBar.bar.runAction(decrease)
            
            if !stormMode && !chargeBar.flashing {
                chargeBar.barFlash.alpha = 0.0

            }
        }
    }
    
    func coinUpdate() {
        if let coinLayer = coinLayer {
            for child in coinLayer.children {
                let coin = child as! Coin
                
                if !coin.collected {
                    if penguin.intersectsNode(coin.body) {
                        // Run coin hit collision
                        incrementTotalCoins()
                        
                        intScore += stormMode ? 4 : 2
                        coin.collected = true

                        let scoreBumpUp = SKAction.scaleTo(1.2, duration: 0.1)
                        let scoreBumpDown = SKAction.scaleTo(1.0, duration: 0.1)
                        scoreLabel.runAction(SKAction.sequence([scoreBumpUp, scoreBumpDown]))
                        
                        coinSound?.currentTime = 0
                        if gameData.soundEffectsOn == true { coinSound?.play() }
                        
                        let rise = SKAction.moveBy(CGVector(dx: 0, dy: coin.body.size.height), duration: 0.5)
                        rise.timingMode = .EaseOut
                        
                        coin.body.zPosition = 90000
                        coin.body.runAction(rise, completion: {
                            coin.generateCoinParticles(self.cam)
                            
                            let path = NSBundle.mainBundle().pathForResource("CoinBurst", ofType: "sks")
                            let coinBurst = NSKeyedUnarchiver.unarchiveObjectWithFile(path!) as! SKEmitterNode
                            
                            coinBurst.zPosition = 240000
                            coinBurst.numParticlesToEmit = 100
                            coinBurst.targetNode = self.scene
                            
                            let coinBurstEffectNode = SKEffectNode()
                            coinBurstEffectNode.addChild(coinBurst)
                            coinBurstEffectNode.zPosition = 240000
                            
                            coinBurstEffectNode.position = self.convertPoint(coin.body.position, fromNode: coin)
                            coinBurstEffectNode.blendMode = .Replace
                            
                            self.addChild(coinBurstEffectNode)
                            
                            if self.gameData.soundEffectsOn as Bool {
                                self.burstSound?.play()
                            }

                            coin.body.removeFromParent()
                            coin.shadow.removeFromParent()
                            self.incrementBarWithCoinParticles(coin)
                        })
                    }
                }
            }
        }
    }
    
    func incrementBarWithCoinParticles(coin: Coin) {
        for particle in coin.particles {
            let chargeBarPositionInCam = cam.convertPoint(chargeBar.position, fromNode: scoreLabel)
            
            let randomX = CGFloat(random()) % (chargeBar.bar.position.x + 1)

            let move = SKAction.moveTo(CGPoint(x: chargeBarPositionInCam.x + randomX, y: chargeBarPositionInCam.y), duration: 1.0)
            move.timingMode = .EaseOut
            
            let wait = SKAction.waitForDuration(0.2 * Double(coin.particles.indexOf(particle)!))
            
            particle.runAction(wait, completion: {
                particle.runAction(move, completion: {
                    particle.removeFromParent()
                    if self.gameData.soundEffectsOn as Bool {
                        let charge = SKAction.playSoundFileNamed("charge.wav", waitForCompletion: false)
                        self.runAction(charge)
                    }
                    
                    self.chargeBar.flashOnce()
                    
                    if !self.stormMode {
                        let incrementAction = SKAction.moveBy(CGVector(dx: self.chargeBar.increment, dy: 0), duration: 0.5)
                        incrementAction.timingMode = .EaseOut
                        self.chargeBar.bar.runAction(incrementAction)
                    } else {
                        // Coin collected during storm mode.
                        // Increment bar but add to time elapsed too.
                    }
                    
                    if coin.particles.isEmpty {
                        coin.removeFromParent()
                    }
                })
            })
        }
    }
    
    func incrementTotalCoins() {
        totalCoins += 1
        
        // Increment coin total in game data
        if gameData != nil {
            let totalCoins = gameData.totalCoins as Int
            gameData.totalCoins = totalCoins + 1
            
            do { try managedObjectContext.save() } catch { print(error) }
        }
    }
    
    func checkGameOver() {
        if !penguin.inAir && !penguin.onBerg! {
            gameOver = true
        }
    }
    
    /*
    func onBerg() -> Bool {
        for child in stage.children {
            let berg = child as! Iceberg
            if penguin.shadow.intersectsNode(berg) {
                return true
            }
        }
        return false
    }
    */
    
    // MARK: - Storm Mode
    
    func beginStorm() {
        stormMode = true
        
        if self.gameData.soundEffectsOn as Bool {
            thunderSound?.play()
        }
        
        windDirectionRight = random() % 2 == 0 ? true : false
        
        waves.stormMode = self.stormMode
        waves.bob()
        
        for child in stage.children {
            let berg = child as! Iceberg
            berg.stormMode = self.stormMode
            berg.bob()
        }
        
        let flashUp = SKAction.fadeAlphaTo(1.0, duration: 0.5)
        let flashDown = SKAction.fadeAlphaTo(0.0, duration: 0.5)
        flashUp.timingMode = .EaseInEaseOut
        flashDown.timingMode = .EaseInEaseOut
        
        let flash = SKAction.sequence([flashUp, flashDown])
        chargeBar.barFlash.runAction(SKAction.repeatActionForever(flash))
    }

    // MARK: - Gameplay logic
    
    func trackDifficulty() {
        // Difficulty:
        // minimum 0.0
        // maximum 1.0
        difficulty = -1.0 * pow(0.9995, Double(penguin.position.y)) + 1.0
    }
    
    // MARK: - Camera control
    
    func centerCamera() {
        if !freezeCamera {
            let cameraFinalDestX = penguin.position.x
            let cameraFinalDestY = penguin.position.y + frame.height / 6
            
            let pan = SKAction.moveTo(CGPoint(x: cameraFinalDestX, y: cameraFinalDestY), duration: 0.125)
            pan.timingMode = .EaseInEaseOut
            
            cam.runAction(pan)
            
            if viewOutlineOn {
                viewFrame.hidden = false
                viewFrame.position = cam.position
            } else {
                viewFrame.hidden = true
            }
        } else {
            cam.removeAllActions()
        }
    }
    
    // MARK: - Audio
    
    func audioPlayerWithFile(file: String, type: String) -> AVAudioPlayer? {
        let path = NSBundle.mainBundle().pathForResource(file, ofType: type)
        let url = NSURL.fileURLWithPath(path!)
        
        var audioPlayer: AVAudioPlayer?
        
        do {
            try audioPlayer = AVAudioPlayer(contentsOfURL: url)
        } catch {
            print("Audio player not available")
        }
        
        return audioPlayer
    }
    
    func fadeVolumeDown(player: AVAudioPlayer) {
        player.volume -= 0.01
        if player.volume < 0.01 {
            player.stop()
        } else {
            // Use afterDelay value to change duration.
            performSelector("fadeVolumeDown:", withObject: player, afterDelay: 0.02)
        }
    }
    
    func fadeVolumeUp(player: AVAudioPlayer ) {
        player.volume += 0.01
        if player.volume < musicVolume {
            performSelector("fadeVolumeUp:", withObject: player, afterDelay: 0.02)
        }
    }
    
    /// Helper function to fade the volume of an `AVAudioPlayer` object.
    func fadeAudioPlayer(player: AVAudioPlayer, fadeTo: Float, duration: NSTimeInterval, completion block: (() -> ())? ) {
        let amount:Float = 0.1
        let incrementDelay = duration * Double(amount)// * amount)
        
        if player.volume > fadeTo + amount {
            player.volume -= amount
            
            delay(incrementDelay) {
                self.fadeAudioPlayer(player, fadeTo: fadeTo, duration: duration, completion: block)
            }
        } else if player.volume < fadeTo - amount {
            player.volume += amount
            
            delay(incrementDelay) {
                self.fadeAudioPlayer(player, fadeTo: fadeTo, duration: duration, completion: block)
            }
        } else {
            // Execute when desired volume reached.
            block?()
        }
        
    }
    
    // MARK: - Utilities
    
    /// Unused delay function with a closure. Not accurate for small increments of time.
    func delay(delay:Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
    
    /// Utility function that is used to shake the screen when the penguin lands on an iceberg to give the illusion of impact.
    func shakeScreen() {
        if enableScreenShake {
            let shakeAnimation = CAKeyframeAnimation(keyPath: "transform")
//            let randomIntensityOne = CGFloat(random() % 4 + 1)
            let randomIntensityTwo = CGFloat(random() % 4 + 1)
            shakeAnimation.values = [
                //NSValue( CATransform3D:CATransform3DMakeTranslation(-randomIntensityOne, 0, 0 ) ),
                //NSValue( CATransform3D:CATransform3DMakeTranslation( randomIntensityOne, 0, 0 ) ),
                NSValue( CATransform3D:CATransform3DMakeTranslation( 0, -randomIntensityTwo, 0 ) ),
                NSValue( CATransform3D:CATransform3DMakeTranslation( 0, randomIntensityTwo, 0 ) ),
            ]
            shakeAnimation.repeatCount = 1
            shakeAnimation.duration = 25/100
            
            view!.layer.addAnimation(shakeAnimation, forKey: nil)
        }
    }
}

/// Overloaded minus operator to use on CGPoint
func -(first: CGPoint, second: CGPoint) -> CGPoint {
    let deltaX = first.x - second.x
    let deltaY = first.y - second.y
    return CGPoint(x: deltaX, y: deltaY)
}

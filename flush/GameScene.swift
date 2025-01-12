//
//  GameScene.swift
//  flush
//
//  Created by 孙韬奋 on 2025/1/11.
//

import SpriteKit
import GameplayKit
import UIKit  // 引入 UIKit 用于震动反馈

// 定义形状类型
enum HoleShape {
    case lightning  // 闪电形状
    case circle    // 圆形
    case triangle  // 三角形
    case custom(path: CGPath)  // 自定义形状
    
    // 生成对应的路径
    func generatePath(radius: CGFloat, center: CGPoint) -> CGPath {
        switch self {
        case .lightning:
            return generateLightningPath(radius: radius, center: center)
        case .circle:
            return generateCirclePath(radius: radius, center: center)
        case .triangle:
            return generateTrianglePath(radius: radius, center: center)
        case .custom(let path):
            // 缩放和移动自定义路径到目标位置
            var transform = CGAffineTransform(scaleX: radius/100, y: radius/100)
            transform = transform.translatedBy(x: center.x, y: center.y)
            return path.copy(using: &transform) ?? path
        }
    }
    
    // 生成闪电形状路径
    private func generateLightningPath(radius: CGFloat, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let numberOfPoints = Int.random(in: 12...18)
        var points: [CGPoint] = []
        
        // 生成基础点
        for i in 0..<numberOfPoints {
            let angle = (CGFloat(i) * 2.0 * .pi) / CGFloat(numberOfPoints)
            let randomRadius = radius * CGFloat.random(in: 0.3...1.7)
            let zigzag = CGFloat.random(in: -20...20)
            let x = center.x + randomRadius * cos(angle) + zigzag
            let y = center.y + randomRadius * sin(angle) + zigzag
            points.append(CGPoint(x: x, y: y))
        }
        
        // 添加锯齿点
        var extraPoints: [CGPoint] = []
        for i in 0..<points.count {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            
            let numberOfExtra = Int.random(in: 1...2)
            for _ in 0..<numberOfExtra {
                let progress = CGFloat.random(in: 0.2...0.8)
                let midX = current.x + (next.x - current.x) * progress
                let midY = current.y + (next.y - current.y) * progress
                
                let offset = CGFloat.random(in: -15...15)
                let perpX = -(next.y - current.y) * offset / 100
                let perpY = (next.x - current.x) * offset / 100
                
                extraPoints.append(CGPoint(x: midX + perpX, y: midY + perpY))
            }
        }
        
        points.append(contentsOf: extraPoints)
        
        // 创建路径
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.closeSubpath()
        return path
    }
    
    // 生成圆形路径
    private func generateCirclePath(radius: CGFloat, center: CGPoint) -> CGPath {
        return CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
    }
    
    // 生成三角形路径
    private func generateTrianglePath(radius: CGFloat, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let points = [
            CGPoint(x: center.x, y: center.y + radius),
            CGPoint(x: center.x - radius * 0.866, y: center.y - radius * 0.5),
            CGPoint(x: center.x + radius * 0.866, y: center.y - radius * 0.5)
        ]
        path.move(to: points[0])
        path.addLine(to: points[1])
        path.addLine(to: points[2])
        path.closeSubpath()
        return path
    }
}

// 游戏设置结构体
struct GameSettings {
    var holeShape: HoleShape = .lightning
    var holesPerBreak: Int = 1
    var holeRadiusRange: ClosedRange<CGFloat> = 30...50
    var customShapes: [CGPath] = []  // 保存用户自定义的形状
}

// 定义可选物体结构体，包含名称和对应的 Emoji
struct AvailableObject {
    let name: String
    let emoji: String
}

class GameScene: SKScene {
    
    // 添加物体节点
    var objectNode: SKSpriteNode!
    
    // 添加物体选择相关节点
    var selectionBackground: SKSpriteNode!
    var objectButtons: [SKNode] = [] // 使用 SKNode 以容纳 Emoji 和标签
    let availableObjects: [AvailableObject] = [
        AvailableObject(name: "bottle", emoji: "🥤"),
        AvailableObject(name: "chair", emoji: "🪑"),
        AvailableObject(name: "woman", emoji: "👩"),
        AvailableObject(name: "man", emoji: "👨")
    ]
    
    // CropNode 和 mask相关
    var cropNode: SKCropNode!
    var maskNode: SKSpriteNode!
    var currentHoleCount = 0
    let holesPerBreak = 1
    let holeRadiusRange: ClosedRange<CGFloat> = 30...50
    
    var gameSettings = GameSettings()
    var isDrawingMode = false
    var drawingPath: CGMutablePath?
    var drawingNode: SKShapeNode?
    
    override func didMove(to view: SKView) {
        // 清除所有现有子节点
        removeAllChildren()
        
        // 显示物体选择界面
        showObjectSelection()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtPoint = nodes(at: location)
        
        for node in nodesAtPoint {
            if node.name == "breakButton" {
                breakObject()
                animateButtonPress(node)
            }
            else if node.name?.hasPrefix("objectButton_") == true {
                let selectedObject = node.name!.replacingOccurrences(of: "objectButton_", with: "")
                selectObject(named: selectedObject)
                animateButtonPress(node)
            }
            else if node.name == "backButton" {
                removeBreakInterface()
                showObjectSelection()
                animateButtonPress(node)
            }
            else if node.name == "settingsButton" {
                showSettings()
                animateButtonPress(node)
            }
            else if node.name?.hasPrefix("shape_") == true || node.name?.hasPrefix("shapeButton_") == true {
                let shapeName = node.name!.replacingOccurrences(of: "shape_", with: "")
                    .replacingOccurrences(of: "shapeButton_", with: "")
                
                if let panel = node.parent?.parent {
                    for child in panel.children {
                        if child.name?.hasPrefix("shapeButton_") == true {
                            (child as? SKSpriteNode)?.color = UIColor(white: 0.3, alpha: 1.0)
                        }
                    }
                }
                
                if let buttonNode = node.name?.hasPrefix("shape_") == true ? node.parent : node {
                    (buttonNode as? SKSpriteNode)?.color = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
                }
                
                switch shapeName {
                case "闪电":
                    gameSettings.holeShape = .lightning
                case "圆形":
                    gameSettings.holeShape = .circle
                case "三角形":
                    gameSettings.holeShape = .triangle
                case "自定义":
                    isDrawingMode = true
                    node.parent?.parent?.removeFromParent()
                default:
                    break
                }
                
                animateButtonPress(node)
            }
            else if node.name == "confirmSettings" {
                node.parent?.removeFromParent()
                animateButtonPress(node)
            }
            else if node.name == "minus_count" {
                if gameSettings.holesPerBreak > 1 {
                    gameSettings.holesPerBreak -= 1
                    if let countLabel = node.parent?.childNode(withName: "countLabel") as? SKLabelNode {
                        countLabel.text = "\(gameSettings.holesPerBreak)"
                    }
                }
                animateButtonPress(node)
            }
            else if node.name == "plus_count" {
                if gameSettings.holesPerBreak < 5 {
                    gameSettings.holesPerBreak += 1
                    if let countLabel = node.parent?.childNode(withName: "countLabel") as? SKLabelNode {
                        countLabel.text = "\(gameSettings.holesPerBreak)"
                    }
                }
                animateButtonPress(node)
            }
            else if node.name == "minus_size" {
                let newSize = max(10, Int(gameSettings.holeRadiusRange.lowerBound) - 5)
                gameSettings.holeRadiusRange = CGFloat(newSize)...CGFloat(newSize + 20)
                if let sizeLabel = node.parent?.childNode(withName: "sizeLabel") as? SKLabelNode {
                    sizeLabel.text = "\(newSize)"
                }
                animateButtonPress(node)
            }
            else if node.name == "plus_size" {
                let newSize = min(100, Int(gameSettings.holeRadiusRange.lowerBound) + 5)
                gameSettings.holeRadiusRange = CGFloat(newSize)...CGFloat(newSize + 20)
                if let sizeLabel = node.parent?.childNode(withName: "sizeLabel") as? SKLabelNode {
                    sizeLabel.text = "\(newSize)"
                }
                animateButtonPress(node)
            }
        }
    }
    
    func breakObject() {
        guard let maskNode = maskNode else { return }
        
        // 创建新的破洞
        for _ in 0..<gameSettings.holesPerBreak {
            let radius = CGFloat.random(in: gameSettings.holeRadiusRange)
            let centerX = CGFloat.random(in: -90...90)
            let centerY = CGFloat.random(in: -90...90)
            let center = CGPoint(x: centerX, y: centerY)
            
            // 使用选择的形状生成路径
            let path = gameSettings.holeShape.generatePath(radius: radius, center: center)
            
            // 创建遮罩洞
            let hole = SKShapeNode(path: path)
            hole.fillColor = .black
            hole.strokeColor = .black
            hole.lineWidth = 0
            hole.blendMode = .replace
            
            // 将洞添加到遮罩节点
            maskNode.addChild(hole)
        }
        
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 添加粒子效果
        if let explosion = SKEmitterNode(fileNamed: "Explosion.sks") {
            explosion.position = .zero
            explosion.zPosition = 15
            explosion.particlePosition = .zero
            explosion.particlePositionRange = CGVector(dx: 50, dy: 50)
            maskNode.parent?.addChild(explosion)
            
            let removeAction = SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ])
            explosion.run(removeAction)
        }
    }
    
    // 显示物体选择界面
    func showObjectSelection() {
        // 创建半透明背景
        selectionBackground = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: size)
        selectionBackground.position = CGPoint(x: size.width / 2, y: size.height / 2)
        selectionBackground.zPosition = 10
        addChild(selectionBackground)
        
        // 创建选择界面标题
        let title = SKLabelNode(text: "请选择一个物体")
        title.fontSize = 28
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: selectionBackground.size.height / 2 - 50)
        title.zPosition = 11
        title.horizontalAlignmentMode = .center
        selectionBackground.addChild(title)
        
        // 创建物体选择按钮及标签
        let buttonSize = CGSize(width: 80, height: 80)
        let padding: CGFloat = 30
        let totalWidth = CGFloat(availableObjects.count) * (buttonSize.width + padding) - padding
        let startX = (size.width - totalWidth) / 2 + buttonSize.width / 2
        let yPosition = size.height / 2
        
        for (index, availableObject) in availableObjects.enumerated() {
            let objectName = availableObject.name
            let objectEmoji = availableObject.emoji
            
            // 创建按钮节点
            let buttonNode = SKNode()
            buttonNode.name = "objectButton_\(objectName)"
            buttonNode.position = CGPoint(x: startX + CGFloat(index) * (buttonSize.width + padding), y: yPosition)
            buttonNode.zPosition = 11
            
            // 添加物体 Emoji
            let emojiLabel = SKLabelNode(text: objectEmoji)
            emojiLabel.fontSize = 40
            emojiLabel.position = CGPoint(x: 0, y: 20)
            emojiLabel.horizontalAlignmentMode = .center
            emojiLabel.verticalAlignmentMode = .center
            buttonNode.addChild(emojiLabel)
            
            // 添加物体名称标签
            let nameLabel = SKLabelNode(text: objectName.capitalized)
            nameLabel.fontSize = 16
            nameLabel.fontColor = .white
            nameLabel.position = CGPoint(x: 0, y: -buttonSize.height / 2 - 10) // 物体名称在 Emoji 下方
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.verticalAlignmentMode = .top
            nameLabel.name = "" // 避免与按钮节点冲突
            buttonNode.addChild(nameLabel)
            
            addChild(buttonNode)
            objectButtons.append(buttonNode)
        }
    }
    
    // 选择物体后更新 objectNode 的图片并移除选择界面
    func selectObject(named objectName: String) {
        // 移除选择界面
        selectionBackground.removeFromParent()
        for button in objectButtons {
            button.removeFromParent()
        }
        objectButtons.removeAll()
        
        // 创建主节点
        let mainNode = SKNode()
        mainNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        mainNode.zPosition = 5
        addChild(mainNode)
        
        // 添加物体节点
        objectNode = SKSpriteNode(imageNamed: objectName)
        objectNode.size = CGSize(width: 200, height: 200)
        objectNode.position = .zero
        mainNode.addChild(objectNode)
        
        // 创建遮罩节点
        maskNode = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 200))
        maskNode.position = .zero
        maskNode.zPosition = 1
        mainNode.addChild(maskNode)
        
        // 添加"轰"按钮
        let breakButton = SKLabelNode(text: "轰")
        breakButton.name = "breakButton"
        breakButton.fontSize = 24
        breakButton.fontColor = .red
        breakButton.position = CGPoint(x: size.width / 2, y: 50)
        breakButton.zPosition = 100 // 确保高于 CropNode
        addChild(breakButton)
        
        // 添加"返回"按钮
        let backButton = SKLabelNode(text: "返回")
        backButton.name = "backButton"
        backButton.fontSize = 20
        backButton.fontColor = .blue
        backButton.position = CGPoint(x: 50, y: size.height - 50)
        backButton.zPosition = 100 // 确保高于 CropNode
        addChild(backButton)
        
        // 创建"轰"按钮背景
        let breakButtonBackground = SKSpriteNode(color: UIColor.red.withAlphaComponent(0.5), size: CGSize(width: 100, height: 50))
        breakButtonBackground.position = breakButton.position
        breakButtonBackground.zPosition = 99 // 背景低于文字
        breakButtonBackground.name = "breakButtonBackground"
        addChild(breakButtonBackground)
        
        // 添加"轰"文字
        let breakButtonLabel = SKLabelNode(text: "轰")
        breakButtonLabel.fontSize = 24
        breakButtonLabel.fontColor = .white
        breakButtonLabel.position = CGPoint.zero
        breakButtonBackground.addChild(breakButtonLabel)
        
        // 同样方式创建"返回"按钮
        let backButtonBackground = SKSpriteNode(color: UIColor.blue.withAlphaComponent(0.5), size: CGSize(width: 80, height: 40))
        backButtonBackground.position = backButton.position
        backButtonBackground.zPosition = 99
        backButtonBackground.name = "backButtonBackground"
        addChild(backButtonBackground)
        
        let backButtonLabel = SKLabelNode(text: "返回")
        backButtonLabel.fontSize = 20
        backButtonLabel.fontColor = .white
        backButtonLabel.position = CGPoint.zero
        backButtonBackground.addChild(backButtonLabel)
        
        // 添加设置按钮
        let settingsButton = SKLabelNode(text: "⚙️")
        settingsButton.name = "settingsButton"
        settingsButton.fontSize = 30
        settingsButton.position = CGPoint(x: size.width - 50, y: size.height - 50)
        settingsButton.zPosition = 100
        addChild(settingsButton)
        
        // 创建设置按钮背景
        let settingsBackground = SKSpriteNode(color: UIColor.gray.withAlphaComponent(0.5), size: CGSize(width: 50, height: 50))
        settingsBackground.position = settingsButton.position
        settingsBackground.zPosition = 99
        settingsBackground.name = "settingsBackground"
        addChild(settingsBackground)
    }
    
    // 移除打破界面元素
    func removeBreakInterface() {
        objectNode?.parent?.removeFromParent()
        objectNode = nil
        maskNode = nil
        
        // 移除"打破"按钮
        if let breakButton = childNode(withName: "breakButton") {
            breakButton.removeFromParent()
        }
        
        // 移除"返回"按钮
        if let backButton = childNode(withName: "backButton") {
            backButton.removeFromParent()
        }
        
        // 移除按钮背景
        if let breakBg = childNode(withName: "breakButtonBackground") {
            breakBg.removeFromParent()
        }
        if let backBg = childNode(withName: "backButtonBackground") {
            backBg.removeFromParent()
        }
    }
    
    // 生成随机遮罩
    func generateRandomMask(size: CGSize, holeCount: Int, holeRadiusRange: ClosedRange<CGFloat>) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            // 填充白色（表示显示部分）
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // 绘制黑色洞（表示隐藏部分）
            for _ in 0..<holeCount {
                let radius = CGFloat.random(in: holeRadiusRange)
                let x = CGFloat.random(in: radius...(size.width - radius))
                let y = CGFloat.random(in: radius...(size.height - radius))
                
                // 创建不规则的破碎形状
                let path = UIBezierPath()
                let numberOfPoints = Int.random(in: 5...8)
                var points: [CGPoint] = []
                
                // 生成随机多边形的顶点
                for i in 0..<numberOfPoints {
                    let angle = (CGFloat(i) * 2.0 * .pi) / CGFloat(numberOfPoints)
                    let randomRadius = radius * CGFloat.random(in: 0.8...1.2)
                    let pointX = x + randomRadius * cos(angle)
                    let pointY = y + randomRadius * sin(angle)
                    points.append(CGPoint(x: pointX, y: pointY))
                }
                
                // 绘制不规则多边形
                path.move(to: points[0])
                for i in 1..<points.count {
                    path.addLine(to: points[i])
                }
                path.close()
                
                UIColor.black.setFill()
                path.fill()
            }
        }
        return img
    }
    
    // 添加绘制相关的函数
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawingMode, let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        if drawingPath == nil {
            drawingPath = CGMutablePath()
            drawingPath?.move(to: location)
            
            drawingNode = SKShapeNode()
            drawingNode?.strokeColor = .white
            drawingNode?.lineWidth = 2
            addChild(drawingNode!)
        } else {
            drawingPath?.addLine(to: location)
            drawingNode?.path = drawingPath
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawingMode {
            if let path = drawingPath {
                // 保存自定义形状
                gameSettings.customShapes.append(path)
                gameSettings.holeShape = .custom(path: path)
            }
            drawingPath = nil
            drawingNode?.removeFromParent()
            drawingNode = nil
            isDrawingMode = false
        }
    }
    
    // 添加设置界面
    func showSettings() {
        // 创建设置面板背景
        let settingsPanel = SKSpriteNode(color: UIColor(white: 0.15, alpha: 0.95), size: CGSize(width: 350, height: 500))
        settingsPanel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        settingsPanel.zPosition = 1000
        settingsPanel.name = "settingsPanel"
        
        // 添加圆角和边框效果
        let borderTexture = SKTexture(imageNamed: "panel_background") // 如果没有这个图片，会自动降级使用纯色背景
        settingsPanel.texture = borderTexture
        addChild(settingsPanel)
        
        // 添加标题
        let titleBackground = SKSpriteNode(color: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0), size: CGSize(width: 350, height: 60))
        titleBackground.position = CGPoint(x: 0, y: 220)
        settingsPanel.addChild(titleBackground)
        
        let title = SKLabelNode(text: "效果设置")
        title.fontSize = 28
        title.fontName = "PingFangSC-Semibold"
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: -10)
        titleBackground.addChild(title)
        
        // 添加形状选择按钮
        let shapes = ["闪电", "圆形", "三角形", "自定义"]
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 50
        let buttonSpacing: CGFloat = 20
        let startY: CGFloat = 130
        
        for (index, shapeName) in shapes.enumerated() {
            let row = index / 2
            let col = index % 2
            let x = CGFloat(col) * (buttonWidth + buttonSpacing) - (buttonWidth + buttonSpacing) / 2
            let y = startY - CGFloat(row) * (buttonHeight + buttonSpacing)
            
            let buttonBackground = SKSpriteNode(color: UIColor(white: 0.3, alpha: 1.0), size: CGSize(width: buttonWidth, height: buttonHeight))
            buttonBackground.position = CGPoint(x: x, y: y)
            buttonBackground.name = "shapeButton_\(shapeName)"
            
            // 如果是当前选中的形状，使用高亮颜色
            switch gameSettings.holeShape {
            case .lightning where shapeName == "闪电",
                 .circle where shapeName == "圆形",
                 .triangle where shapeName == "三角形",
                 .custom where shapeName == "自定义":
                buttonBackground.color = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
            default:
                break
            }
            
            settingsPanel.addChild(buttonBackground)
            
            let button = SKLabelNode(text: shapeName)
            button.fontSize = 24
            button.fontName = "PingFangSC-Regular"
            button.fontColor = .white
            button.position = CGPoint(x: 0, y: -8)
            button.name = "shape_\(shapeName)"
            buttonBackground.addChild(button)
        }
        
        // 添加数量调节器
        let countTitle = SKLabelNode(text: "破坏数量")
        countTitle.fontSize = 20
        countTitle.fontName = "PingFangSC-Regular"
        countTitle.fontColor = .white
        countTitle.position = CGPoint(x: -120, y: 0)
        settingsPanel.addChild(countTitle)
        
        // 添加减号按钮
        let minusButton = SKShapeNode(circleOfRadius: 20)
        minusButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        minusButton.strokeColor = .clear
        minusButton.position = CGPoint(x: -50, y: 0)
        minusButton.name = "minus_count"
        settingsPanel.addChild(minusButton)
        
        let minusLabel = SKLabelNode(text: "-")
        minusLabel.fontSize = 30
        minusLabel.fontColor = .white
        minusLabel.position = CGPoint(x: 0, y: -10)
        minusButton.addChild(minusLabel)
        
        // 添加数量显示
        let countLabel = SKLabelNode(text: "\(gameSettings.holesPerBreak)")
        countLabel.fontSize = 24
        countLabel.fontName = "PingFangSC-Medium"
        countLabel.fontColor = .white
        countLabel.position = CGPoint(x: 0, y: 0)
        countLabel.name = "countLabel"
        settingsPanel.addChild(countLabel)
        
        // 添加加号按钮
        let plusButton = SKShapeNode(circleOfRadius: 20)
        plusButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        plusButton.strokeColor = .clear
        plusButton.position = CGPoint(x: 50, y: 0)
        plusButton.name = "plus_count"
        settingsPanel.addChild(plusButton)
        
        let plusLabel = SKLabelNode(text: "+")
        plusLabel.fontSize = 30
        plusLabel.fontColor = .white
        plusLabel.position = CGPoint(x: 0, y: -10)
        plusButton.addChild(plusLabel)
        
        // 添加大小调节器
        let sizeTitle = SKLabelNode(text: "破坏大小")
        sizeTitle.fontSize = 20
        sizeTitle.fontName = "PingFangSC-Regular"
        sizeTitle.fontColor = .white
        sizeTitle.position = CGPoint(x: -120, y: -80)
        settingsPanel.addChild(sizeTitle)
        
        // 添加大小减号按钮
        let minusSizeButton = SKShapeNode(circleOfRadius: 20)
        minusSizeButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        minusSizeButton.strokeColor = .clear
        minusSizeButton.position = CGPoint(x: -50, y: -80)
        minusSizeButton.name = "minus_size"
        settingsPanel.addChild(minusSizeButton)
        
        let minusSizeLabel = SKLabelNode(text: "-")
        minusSizeLabel.fontSize = 30
        minusSizeLabel.fontColor = .white
        minusSizeLabel.position = CGPoint(x: 0, y: -10)
        minusSizeButton.addChild(minusSizeLabel)
        
        // 添加大小显示
        let sizeLabel = SKLabelNode(text: "\(Int(gameSettings.holeRadiusRange.lowerBound))")
        sizeLabel.fontSize = 24
        sizeLabel.fontName = "PingFangSC-Medium"
        sizeLabel.fontColor = .white
        sizeLabel.position = CGPoint(x: 0, y: -80)
        sizeLabel.name = "sizeLabel"
        settingsPanel.addChild(sizeLabel)
        
        // 添加大小加号按钮
        let plusSizeButton = SKShapeNode(circleOfRadius: 20)
        plusSizeButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        plusSizeButton.strokeColor = .clear
        plusSizeButton.position = CGPoint(x: 50, y: -80)
        plusSizeButton.name = "plus_size"
        settingsPanel.addChild(plusSizeButton)
        
        let plusSizeLabel = SKLabelNode(text: "+")
        plusSizeLabel.fontSize = 30
        plusSizeLabel.fontColor = .white
        plusSizeLabel.position = CGPoint(x: 0, y: -10)
        plusSizeButton.addChild(plusSizeLabel)
        
        // 添加确认按钮
        let confirmButton = SKSpriteNode(color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0), size: CGSize(width: 200, height: 50))
        confirmButton.position = CGPoint(x: 0, y: -180)
        confirmButton.name = "confirmSettings"
        settingsPanel.addChild(confirmButton)
        
        let confirmLabel = SKLabelNode(text: "确认")
        confirmLabel.fontSize = 24
        confirmLabel.fontName = "PingFangSC-Medium"
        confirmLabel.fontColor = .white
        confirmLabel.position = CGPoint(x: 0, y: -8)
        confirmButton.addChild(confirmLabel)
    }
    
    // 添加按钮按压动画
    func animateButtonPress(_ node: SKNode) {
        let scaleDown = SKAction.scale(to: 0.9, duration: 0.05)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.05)
        node.run(SKAction.sequence([scaleDown, scaleUp]))
    }
}

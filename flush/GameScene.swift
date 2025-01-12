//
//  GameScene.swift
//  flush
//
//  Created by 孙韬奋 on 2025/1/11.
//

import SpriteKit
import GameplayKit
import UIKit  // 引入 UIKit 用于震动反馈

// 在文件顶部添加扩展
extension UIImage {
    static func image(from layer: CALayer) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(layer.bounds.size, layer.isOpaque, 0.0)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

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

// 在 GameSettings 结构体中添加自定义形状管理
struct CustomShapeInfo {
    let name: String
    let path: CGPath
    let createdAt: Date
}

// 游戏设置结构体
struct GameSettings {
    var holeShape: HoleShape = .lightning
    var holesPerBreak: Int = 1
    var holeRadiusRange: ClosedRange<CGFloat> = 30...50
    var customShapes: [CustomShapeInfo] = []  // 修改为存储CustomShapeInfo
    
    mutating func addCustomShape(path: CGPath, name: String? = nil) {
        let shapeName = name ?? DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let shapeInfo = CustomShapeInfo(name: shapeName, path: path, createdAt: Date())
        customShapes.append(shapeInfo)
    }
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
    
    var tooltipNode: SKNode?
    var drawingPanel: SKSpriteNode?
    var isShowingCustomShapes = false
    
    override func didMove(to view: SKView) {
        // 生成背景图片
        generatePanelBackground()
        
        // 清除所有现有子节点
        removeAllChildren()
        
        // 显示物体选择界面
        showObjectSelection()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 获取点击位置的所有节点
        let nodesAtPoint = nodes(at: location)
        
        // 如果在绘图模式下，处理绘图相关的点击
        if isDrawingMode {
            // 检查是否点击了取消按钮
            if nodesAtPoint.contains(where: { $0.name == "cancelDrawing" || $0.parent?.name == "cancelDrawing" }) {
                cleanupDrawingPanel()
                return
            }
            
            // 检查是否点击了保存按钮
            if nodesAtPoint.contains(where: { $0.name == "saveDrawing" || $0.parent?.name == "saveDrawing" }) {
                if let path = drawingPath {
                    // 创建一个新的路径，将绘制的路径转换为相对于中心点的坐标
                    let bounds = drawingNode?.path?.boundingBox ?? .zero
                    let centerX = bounds.midX
                    let centerY = bounds.midY
                    
                    // 创建一个变换，将路径移动到原点并缩放到合适的大小
                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: -centerX, y: -centerY)
                    
                    // 将原始路径应用变换
                    if let transformedPath = path.copy(using: &transform) {
                        // 显示输入框让用户输入名称
                        let alertController = UIAlertController(
                            title: "保存形状",
                            message: "请为这个形状命名",
                            preferredStyle: .alert
                        )
                        
                        alertController.addTextField { textField in
                            textField.placeholder = "形状名称"
                            // 设置默认名称为当前时间
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "MM-dd HH:mm"
                            textField.text = "形状_" + dateFormatter.string(from: Date())
                        }
                        
                        let saveAction = UIAlertAction(title: "保存", style: .default) { [weak self] _ in
                            guard let self = self else { return }
                            let name = alertController.textFields?.first?.text ?? "未命名形状"
                            
                            // 保存转换后的路径
                            self.gameSettings.addCustomShape(path: transformedPath, name: name)
                            
                            // 清理绘图面板
                            self.cleanupDrawingPanel()
                        }
                        
                        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
                            guard let self = self else { return }
                            self.cleanupDrawingPanel()
                        }
                        
                        alertController.addAction(saveAction)
                        alertController.addAction(cancelAction)
                        
                        // 获取当前场景的视图控制器并显示警告框
                        if let viewController = self.view?.window?.rootViewController {
                            viewController.present(alertController, animated: true)
                        }
                    }
                }
                return
            }
            
            // 如果在绘图区域内，开始绘制
            if let drawArea = drawingPanel?.childNode(withName: "drawArea") {
                let locationInDrawArea = drawArea.convert(location, from: self)
                
                // 检查是否在绘制区域内
                if abs(locationInDrawArea.x) <= drawArea.frame.width/2 &&
                   abs(locationInDrawArea.y) <= drawArea.frame.height/2 {
                    // 创建新的路径
                    drawingPath = CGMutablePath()
                    drawingPath?.move(to: locationInDrawArea)
                    
                    // 创建或更新绘制节点
                    if drawingNode == nil {
                        drawingNode = SKShapeNode()
                        drawingNode?.strokeColor = .white
                        drawingNode?.lineWidth = 2
                        drawArea.addChild(drawingNode!)
                    }
                    drawingNode?.path = drawingPath
                    return
                }
            }
            return
        }
        
        // 处理其他按钮点击
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
                
                // 重置所有形状按钮的颜色
                if let panel = node.parent?.parent {
                    for child in panel.children {
                        if child.name?.hasPrefix("shapeButton_") == true {
                            (child as? SKSpriteNode)?.color = UIColor(white: 0.3, alpha: 1.0)
                        }
                    }
                }
                
                // 高亮选中的按钮
                if let buttonNode = node.name?.hasPrefix("shape_") == true ? node.parent : node {
                    (buttonNode as? SKSpriteNode)?.color = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
                }
                
                // 处理形状选择
                if shapeName.hasPrefix("custom_") {
                    // 处理已保存的自定义形状
                    if let index = Int(shapeName.replacingOccurrences(of: "custom_", with: "")) {
                        let shapeInfo = gameSettings.customShapes[index]
                        gameSettings.holeShape = .custom(path: shapeInfo.path)
                    }
                } else {
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
                        showDrawingPanel()
                    default:
                        break
                    }
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
            else if node.name == "helpCount" || node.parent?.name == "helpCount" || node.name == "?" {
                let helpNode = node.name == "helpCount" ? node : 
                              node.parent?.name == "helpCount" ? node.parent! : 
                              node.parent!
                showTooltip(text: "每次点击轰按钮时产生的破坏数量", at: helpNode)
                animateButtonPress(helpNode)
            }
            else if node.name == "helpSize" || node.parent?.name == "helpSize" || (node.name == "?" && node.parent?.name == "helpSize") {
                let helpNode = node.name == "helpSize" ? node : 
                              node.parent?.name == "helpSize" ? node.parent! : 
                              node.parent!
                showTooltip(text: "破坏效果的范围大小", at: helpNode)
                animateButtonPress(helpNode)
            }
            else if node.name?.hasPrefix("shape_") == true && node.name?.contains("自定义") == true {
                showCustomShapesList()
            }
            else if node.name == "newCustomShape" {
                node.parent?.removeFromParent()
                showDrawingPanel()
            }
            else if node.name?.hasPrefix("customShape_") == true {
                if let index = Int(node.name!.replacingOccurrences(of: "customShape_", with: "")) {
                    let shapeInfo = gameSettings.customShapes[index]
                    gameSettings.holeShape = .custom(path: shapeInfo.path)
                    node.parent?.removeFromParent()
                }
            }
            
            // 如果点击了其他区域，隐藏提示
            if node.name?.hasPrefix("help") != true {
                hideTooltip()
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
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 如果在绘图模式下，继续绘制
        if isDrawingMode, let drawArea = drawingPanel?.childNode(withName: "drawArea"),
           let path = drawingPath {
            let locationInDrawArea = drawArea.convert(location, from: self)
            
            // 检查是否在绘制区域内
            if abs(locationInDrawArea.x) <= drawArea.frame.width/2 &&
               abs(locationInDrawArea.y) <= drawArea.frame.height/2 {
                // 添加线段到路径
                path.addLine(to: locationInDrawArea)
                drawingNode?.path = path
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 如果在绘图模式下，结束绘制
        if isDrawingMode, let drawArea = drawingPanel?.childNode(withName: "drawArea"),
           let path = drawingPath {
            let locationInDrawArea = drawArea.convert(location, from: self)
            
            // 检查是否点击了保存或取消按钮
            if let nodes = scene?.nodes(at: location) {
                for node in nodes {
                    if node.name == "saveDrawing" || node.name == "cancelDrawing" {
                        return  // 如果点击了按钮，不添加点
                    }
                }
            }
            
            // 只有在绘制区域内才添加点
            if abs(locationInDrawArea.x) <= drawArea.frame.width/2 &&
               abs(locationInDrawArea.y) <= drawArea.frame.height/2 {
                path.addLine(to: locationInDrawArea)
                path.closeSubpath()
                drawingNode?.path = path
            }
        }
    }
    
    // 添加设置界面
    func showSettings() {
        // 创建设置面板背景
        let settingsPanel = SKSpriteNode(color: UIColor(white: 0.15, alpha: 0.95), size: CGSize(width: 350, height: 500))
        settingsPanel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        settingsPanel.zPosition = 1000
        settingsPanel.name = "settingsPanel"
        
        // 添加背景图片和效果
        let backgroundTexture = SKTexture(imageNamed: "panel_background")
        if backgroundTexture.size().width > 0 {  // 检查纹理是否有效
            settingsPanel.texture = backgroundTexture
            settingsPanel.color = UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)
            settingsPanel.colorBlendFactor = 0.3 // 添加一点颜色混合
        } else {
            // 如果没有背景图片，创建渐变背景
            let gradientNode = SKSpriteNode(color: .clear, size: settingsPanel.size)
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(origin: .zero, size: settingsPanel.size)
            gradientLayer.colors = [
                UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.95).cgColor,
                UIColor(red: 0.1, green: 0.15, blue: 0.2, alpha: 0.95).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.cornerRadius = 20
            
            let gradientImage = UIImage.image(from: gradientLayer)
            gradientNode.texture = SKTexture(image: gradientImage)
            gradientNode.zPosition = -1
            settingsPanel.addChild(gradientNode)
        }
        
        // 添加边框效果
        let borderNode = SKShapeNode(rect: CGRect(x: -settingsPanel.size.width/2, y: -settingsPanel.size.height/2,
                                                 width: settingsPanel.size.width, height: settingsPanel.size.height),
                                   cornerRadius: 20)
        borderNode.strokeColor = UIColor(white: 1.0, alpha: 0.2)
        borderNode.lineWidth = 2
        settingsPanel.addChild(borderNode)
        
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
        let shapes = ["闪电", "圆形", "三角形"]
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 50
        let buttonSpacing: CGFloat = 20
        let startY: CGFloat = 150  // 调整起始Y坐标
        
        // 添加形状选择标题
        let shapesTitle = SKLabelNode(text: "形状选择")
        shapesTitle.fontSize = 20
        shapesTitle.fontName = "PingFangSC-Regular"
        shapesTitle.fontColor = .white
        shapesTitle.position = CGPoint(x: -120, y: 100)
        settingsPanel.addChild(shapesTitle)
        
        // 添加第一条分隔线
        let separator1 = SKShapeNode(rectOf: CGSize(width: 300, height: 1))
        separator1.fillColor = UIColor(white: 0.5, alpha: 0.5)
        separator1.strokeColor = UIColor.clear
        separator1.position = CGPoint(x: 0, y: -40)
        settingsPanel.addChild(separator1)
        
        // 添加数量控制标题
        let quantityTitle = SKLabelNode(text: "破坏数量")
        quantityTitle.fontSize = 20
        quantityTitle.fontName = "PingFangSC-Regular"
        quantityTitle.fontColor = .white
        quantityTitle.position = CGPoint(x: -120, y: -100)
        settingsPanel.addChild(quantityTitle)
        
        // 添加控制区域分隔线
        let controlSeparator = SKShapeNode(rectOf: CGSize(width: 300, height: 1))
        controlSeparator.fillColor = UIColor(white: 0.5, alpha: 0.5)
        controlSeparator.strokeColor = UIColor.clear
        controlSeparator.position = CGPoint(x: 0, y: -130)
        settingsPanel.addChild(controlSeparator)
        
        // 添加预设形状按钮
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
                 .triangle where shapeName == "三角形":
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
        
        // 添加自定义形状按钮
        let customButtonBackground = SKSpriteNode(color: UIColor(white: 0.3, alpha: 1.0), size: CGSize(width: buttonWidth, height: buttonHeight))
        customButtonBackground.position = CGPoint(x: -70, y: startY - CGFloat(2) * (buttonHeight + buttonSpacing))
        customButtonBackground.name = "shapeButton_自定义"
        settingsPanel.addChild(customButtonBackground)
        
        let customButton = SKLabelNode(text: "自定义")
        customButton.fontSize = 24
        customButton.fontName = "PingFangSC-Regular"
        customButton.fontColor = .white
        customButton.position = CGPoint(x: 0, y: -8)
        customButton.name = "shape_自定义"
        customButtonBackground.addChild(customButton)
        
        // 如果有已保存的自定义形状，添加查看按钮
        if !gameSettings.customShapes.isEmpty {
            let savedButtonBackground = SKSpriteNode(color: UIColor(white: 0.3, alpha: 1.0), size: CGSize(width: buttonWidth, height: buttonHeight))
            savedButtonBackground.position = CGPoint(x: 70, y: startY - CGFloat(2) * (buttonHeight + buttonSpacing))
            savedButtonBackground.name = "shapeButton_saved"
            settingsPanel.addChild(savedButtonBackground)
            
            let savedButton = SKLabelNode(text: "已保存")
            savedButton.fontSize = 24
            savedButton.fontName = "PingFangSC-Regular"
            savedButton.fontColor = .white
            savedButton.position = CGPoint(x: 0, y: -8)
            savedButton.name = "shape_saved"
            savedButtonBackground.addChild(savedButton)
        }
        
        // 添加第二个分隔线
        let separator2 = SKShapeNode(rectOf: CGSize(width: 300, height: 1))
        separator2.fillColor = UIColor(white: 0.5, alpha: 0.5)
        separator2.strokeColor = .clear
        separator2.position = CGPoint(x: 0, y: -130)
        settingsPanel.addChild(separator2)
        
        // 添加数量和大小控制区域标题
        let controlTitle = SKLabelNode(text: "效果控制")
        controlTitle.fontSize = 20
        controlTitle.fontName = "PingFangSC-Regular"
        controlTitle.fontColor = .white
        controlTitle.position = CGPoint(x: 0, y: -70)
        settingsPanel.addChild(controlTitle)
        
        // 添加帮助按钮
        let countHelpButton = SKShapeNode(circleOfRadius: 10)
        countHelpButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        countHelpButton.strokeColor = .white
        countHelpButton.lineWidth = 1
        countHelpButton.position = CGPoint(x: -80, y: -100)  // 调整Y坐标
        countHelpButton.name = "helpCount"
        settingsPanel.addChild(countHelpButton)
        
        let countHelpLabel = SKLabelNode(text: "?")
        countHelpLabel.fontSize = 14
        countHelpLabel.fontName = "PingFangSC-Medium"
        countHelpLabel.fontColor = .white
        countHelpLabel.position = CGPoint(x: 0, y: -5)
        countHelpButton.addChild(countHelpLabel)
        
        // 添加数量控制器
        let minusButton = SKShapeNode(circleOfRadius: 20)
        minusButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        minusButton.strokeColor = .clear
        minusButton.position = CGPoint(x: -50, y: -100)  // 调整Y坐标
        minusButton.name = "minus_count"
        settingsPanel.addChild(minusButton)
        
        let minusLabel = SKLabelNode(text: "-")
        minusLabel.fontSize = 30
        minusLabel.fontColor = .white
        minusLabel.position = CGPoint(x: 0, y: -10)
        minusButton.addChild(minusLabel)
        
        let countLabel = SKLabelNode(text: "\(gameSettings.holesPerBreak)")
        countLabel.fontSize = 24
        countLabel.fontName = "PingFangSC-Medium"
        countLabel.fontColor = .white
        countLabel.position = CGPoint(x: 0, y: -100)  // 调整Y坐标
        countLabel.name = "countLabel"
        settingsPanel.addChild(countLabel)
        
        let plusButton = SKShapeNode(circleOfRadius: 20)
        plusButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        plusButton.strokeColor = .clear
        plusButton.position = CGPoint(x: 50, y: -100)  // 调整Y坐标
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
        sizeTitle.position = CGPoint(x: -120, y: -160)  // 调整Y坐标
        settingsPanel.addChild(sizeTitle)
        
        // 添加大小帮助按钮
        let sizeHelpButton = SKShapeNode(circleOfRadius: 10)
        sizeHelpButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        sizeHelpButton.strokeColor = .white
        sizeHelpButton.lineWidth = 1
        sizeHelpButton.position = CGPoint(x: -80, y: -160)  // 调整Y坐标
        sizeHelpButton.name = "helpSize"
        settingsPanel.addChild(sizeHelpButton)
        
        let sizeHelpLabel = SKLabelNode(text: "?")
        sizeHelpLabel.fontSize = 14
        sizeHelpLabel.fontName = "PingFangSC-Medium"
        sizeHelpLabel.fontColor = .white
        sizeHelpLabel.position = CGPoint(x: 0, y: -5)
        sizeHelpButton.addChild(sizeHelpLabel)
        
        // 添加大小控制器
        let minusSizeButton = SKShapeNode(circleOfRadius: 20)
        minusSizeButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        minusSizeButton.strokeColor = .clear
        minusSizeButton.position = CGPoint(x: -50, y: -160)  // 调整Y坐标
        minusSizeButton.name = "minus_size"
        settingsPanel.addChild(minusSizeButton)
        
        let minusSizeLabel = SKLabelNode(text: "-")
        minusSizeLabel.fontSize = 30
        minusSizeLabel.fontColor = .white
        minusSizeLabel.position = CGPoint(x: 0, y: -10)
        minusSizeButton.addChild(minusSizeLabel)
        
        let sizeLabel = SKLabelNode(text: "\(Int(gameSettings.holeRadiusRange.lowerBound))")
        sizeLabel.fontSize = 24
        sizeLabel.fontName = "PingFangSC-Medium"
        sizeLabel.fontColor = .white
        sizeLabel.position = CGPoint(x: 0, y: -160)  // 调整Y坐标
        sizeLabel.name = "sizeLabel"
        settingsPanel.addChild(sizeLabel)
        
        let plusSizeButton = SKShapeNode(circleOfRadius: 20)
        plusSizeButton.fillColor = UIColor(white: 0.3, alpha: 1.0)
        plusSizeButton.strokeColor = .clear
        plusSizeButton.position = CGPoint(x: 50, y: -160)  // 调整Y坐标
        plusSizeButton.name = "plus_size"
        settingsPanel.addChild(plusSizeButton)
        
        let plusSizeLabel = SKLabelNode(text: "+")
        plusSizeLabel.fontSize = 30
        plusSizeLabel.fontColor = .white
        plusSizeLabel.position = CGPoint(x: 0, y: -10)
        plusSizeButton.addChild(plusSizeLabel)
        
        // 添加确认按钮
        let confirmButton = SKSpriteNode(color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0), size: CGSize(width: 200, height: 50))
        confirmButton.position = CGPoint(x: 0, y: -220)  // 调整Y坐标
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
    
    // 在 GameScene 类中添加生成背景的函数
    func generatePanelBackground() {
        // 创建渐变图层
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: 700, height: 1000)) // 2x 大小
        
        // 设置渐变颜色
        gradientLayer.colors = [
            UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.98).cgColor,
            UIColor(red: 0.15, green: 0.2, blue: 0.3, alpha: 0.98).cgColor,
            UIColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 0.98).cgColor
        ]
        
        // 设置渐变点
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        
        // 添加圆角
        gradientLayer.cornerRadius = 40 // 2x 大小的圆角
        
        // 创建一个图形上下文
        UIGraphicsBeginImageContextWithOptions(gradientLayer.frame.size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 渲染渐变层
        gradientLayer.render(in: context)
        
        // 添加内部光晕效果
        let glowPath = UIBezierPath(roundedRect: gradientLayer.bounds.insetBy(dx: 20, dy: 20),
                                  cornerRadius: 35)
        context.saveGState()
        context.setLineWidth(15)
        context.setShadow(offset: .zero, blur: 15, color: UIColor(white: 1, alpha: 0.3).cgColor)
        UIColor(white: 1, alpha: 0.1).setStroke()
        glowPath.stroke()
        context.restoreGState()
        
        // 添加图案效果
        let patternSize: CGFloat = 50
        let patternColor = UIColor(white: 1, alpha: 0.03)
        
        for row in 0...Int(gradientLayer.frame.height/patternSize) {
            for col in 0...Int(gradientLayer.frame.width/patternSize) {
                let x = CGFloat(col) * patternSize
                let y = CGFloat(row) * patternSize
                
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + patternSize/2, y: y + patternSize/2))
                
                patternColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }
        
        // 获取生成的图像
        guard let image = UIGraphicsGetCurrentContext()?.makeImage() else { return }
        UIGraphicsEndImageContext()
        
        // 将图像保存到文件
        if let data = UIImage(cgImage: image).pngData(),
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsPath.appendingPathComponent("panel_background.png")
            try? data.write(to: fileURL)
            print("Background saved to: \(fileURL.path)")
        }
    }
    
    // 添加显示提示的函数
    func showTooltip(text: String, at node: SKNode) {
        // 移除现有的提示
        tooltipNode?.removeFromParent()
        
        // 创建提示框
        let tooltipWidth: CGFloat = 220
        let tooltipHeight: CGFloat = 50
        let tooltip = SKSpriteNode(color: UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.95), size: CGSize(width: tooltipWidth, height: tooltipHeight))
        tooltip.position = CGPoint(x: node.position.x + tooltipWidth/2 + 20, y: node.position.y)
        tooltip.zPosition = 3000
        
        // 添加边框
        let border = SKShapeNode(rect: CGRect(x: -tooltipWidth/2, y: -tooltipHeight/2,
                                            width: tooltipWidth, height: tooltipHeight),
                               cornerRadius: 10)
        border.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        border.lineWidth = 1
        tooltip.addChild(border)
        
        // 添加文本
        let label = SKLabelNode(text: text)
        label.fontSize = 16
        label.fontName = "PingFangSC-Regular"
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -8)
        tooltip.addChild(label)
        
        // 添加到父节点
        node.parent?.addChild(tooltip)
        tooltipNode = tooltip
        
        // 添加动画效果
        tooltip.setScale(0.5)
        tooltip.alpha = 0
        let scaleAction = SKAction.scale(to: 1.0, duration: 0.2)
        let fadeAction = SKAction.fadeIn(withDuration: 0.2)
        tooltip.run(SKAction.group([scaleAction, fadeAction]))
    }
    
    // 添加隐藏提示的函数
    func hideTooltip() {
        tooltipNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        tooltipNode = nil
    }
    
    // 显示绘制面板
    func showDrawingPanel() {
        // 创建绘制面板背景
        let panel = SKSpriteNode(color: UIColor(white: 0.1, alpha: 0.95), size: CGSize(width: size.width * 0.8, height: size.height * 0.8))
        panel.position = CGPoint(x: size.width/2, y: size.height/2)
        panel.zPosition = 2000
        
        // 添加边框效果
        let borderNode = SKShapeNode(rect: CGRect(x: -panel.size.width/2, y: -panel.size.height/2,
                                                 width: panel.size.width, height: panel.size.height),
                                   cornerRadius: 20)
        borderNode.strokeColor = UIColor(white: 1.0, alpha: 0.2)
        borderNode.lineWidth = 2
        panel.addChild(borderNode)
        
        // 添加标题背景
        let titleBg = SKSpriteNode(color: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0),
                                 size: CGSize(width: panel.size.width, height: 60))
        titleBg.position = CGPoint(x: 0, y: panel.size.height/2 - 30)
        panel.addChild(titleBg)
        
        // 添加标题
        let title = SKLabelNode(text: "绘制自定义形状")
        title.fontSize = 24
        title.fontName = "PingFangSC-Medium"
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: -10)
        titleBg.addChild(title)
        
        // 添加绘制区域
        let drawArea = SKSpriteNode(color: UIColor(white: 0.2, alpha: 1.0),
                                  size: CGSize(width: panel.size.width * 0.8, height: panel.size.height * 0.6))
        drawArea.position = CGPoint(x: 0, y: 0)
        drawArea.name = "drawArea"
        
        // 添加绘制区域边框
        let drawAreaBorder = SKShapeNode(rect: CGRect(x: -drawArea.size.width/2, y: -drawArea.size.height/2,
                                                     width: drawArea.size.width, height: drawArea.size.height),
                                       cornerRadius: 10)
        drawAreaBorder.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        drawAreaBorder.lineWidth = 2
        drawArea.addChild(drawAreaBorder)
        
        panel.addChild(drawArea)
        
        // 添加说明文字
        let instruction = SKLabelNode(text: "在此区域内绘制形状")
        instruction.fontSize = 16
        instruction.fontName = "PingFangSC-Regular"
        instruction.fontColor = UIColor(white: 0.8, alpha: 1.0)
        instruction.position = CGPoint(x: 0, y: drawArea.position.y + drawArea.size.height/2 + 20)
        panel.addChild(instruction)
        
        // 添加提示文字
        let hint = SKLabelNode(text: "提示：绘制一个闭合的形状作为破坏效果")
        hint.fontSize = 14
        hint.fontName = "PingFangSC-Regular"
        hint.fontColor = UIColor(white: 0.7, alpha: 1.0)
        hint.position = CGPoint(x: 0, y: drawArea.position.y - drawArea.size.height/2 - 20)
        panel.addChild(hint)
        
        // 添加保存按钮
        let saveButton = SKSpriteNode(color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0),
                                    size: CGSize(width: 120, height: 40))
        saveButton.position = CGPoint(x: -70, y: -panel.size.height/2 + 40)
        saveButton.name = "saveDrawing"
        
        // 添加保存按钮边框
        let saveBorder = SKShapeNode(rect: CGRect(x: -60, y: -20, width: 120, height: 40), cornerRadius: 8)
        saveBorder.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        saveBorder.lineWidth = 1
        saveButton.addChild(saveBorder)
        
        panel.addChild(saveButton)
        
        let saveLabel = SKLabelNode(text: "保存")
        saveLabel.fontSize = 18
        saveLabel.fontName = "PingFangSC-Regular"
        saveLabel.fontColor = .white
        saveLabel.position = CGPoint(x: 0, y: -5)
        saveButton.addChild(saveLabel)
        
        // 添加取消按钮
        let cancelButton = SKSpriteNode(color: UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0),
                                      size: CGSize(width: 120, height: 40))
        cancelButton.position = CGPoint(x: 70, y: -panel.size.height/2 + 40)
        cancelButton.name = "cancelDrawing"
        
        // 添加取消按钮边框
        let cancelBorder = SKShapeNode(rect: CGRect(x: -60, y: -20, width: 120, height: 40), cornerRadius: 8)
        cancelBorder.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        cancelBorder.lineWidth = 1
        cancelButton.addChild(cancelBorder)
        
        panel.addChild(cancelButton)
        
        let cancelLabel = SKLabelNode(text: "取消")
        cancelLabel.fontSize = 18
        cancelLabel.fontName = "PingFangSC-Regular"
        cancelLabel.fontColor = .white
        cancelLabel.position = CGPoint(x: 0, y: -5)
        cancelButton.addChild(cancelLabel)
        
        drawingPanel = panel
        addChild(panel)
        
        // 添加出现动画
        panel.setScale(0.5)
        panel.alpha = 0
        let scaleAction = SKAction.scale(to: 1.0, duration: 0.3)
        let fadeAction = SKAction.fadeIn(withDuration: 0.3)
        panel.run(SKAction.group([scaleAction, fadeAction]))
    }
    
    // 显示自定义形状列表
    func showCustomShapesList() {
        let panel = SKSpriteNode(color: UIColor(white: 0.1, alpha: 0.95), size: CGSize(width: 300, height: 400))
        panel.position = CGPoint(x: size.width/2, y: size.height/2)
        panel.zPosition = 2000
        panel.name = "customShapesPanel"
        
        // 添加标题
        let title = SKLabelNode(text: "已保存的形状")
        title.fontSize = 24
        title.fontName = "PingFangSC-Medium"
        title.position = CGPoint(x: 0, y: panel.size.height/2 - 40)
        panel.addChild(title)
        
        // 显示保存的形状列表
        let startY = panel.size.height/2 - 100
        for (index, shapeInfo) in gameSettings.customShapes.enumerated() {
            let itemBg = SKSpriteNode(color: UIColor(white: 0.2, alpha: 1.0), size: CGSize(width: 260, height: 50))
            itemBg.position = CGPoint(x: 0, y: startY - CGFloat(index * 60))
            itemBg.name = "customShape_\(index)"
            panel.addChild(itemBg)
            
            let nameLabel = SKLabelNode(text: shapeInfo.name)
            nameLabel.fontSize = 16
            nameLabel.fontName = "PingFangSC-Regular"
            nameLabel.position = CGPoint(x: 0, y: -8)
            itemBg.addChild(nameLabel)
        }
        
        // 添加新建按钮
        let newButton = SKSpriteNode(color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0), size: CGSize(width: 260, height: 50))
        newButton.position = CGPoint(x: 0, y: -panel.size.height/2 + 40)
        newButton.name = "newCustomShape"
        panel.addChild(newButton)
        
        let newLabel = SKLabelNode(text: "新建形状")
        newLabel.fontSize = 18
        newLabel.fontName = "PingFangSC-Regular"
        newLabel.position = CGPoint(x: 0, y: -8)
        newButton.addChild(newLabel)
        
        addChild(panel)
    }
    
    // 清理绘图面板
    func cleanupDrawingPanel() {
        // 移除所有绘图相关的节点
        drawingPanel?.removeFromParent()
        drawingNode?.removeFromParent()
        
        // 重置所有绘图相关的变量
        drawingPanel = nil
        drawingPath = nil
        drawingNode = nil
        isDrawingMode = false
        
        // 重新显示设置面板
        showSettings()
    }
}

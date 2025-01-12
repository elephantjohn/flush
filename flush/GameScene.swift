//
//  GameScene.swift
//  flush
//
//  Created by 孙韬奋 on 2025/1/11.
//

import SpriteKit
import GameplayKit
import UIKit  // 引入 UIKit 用于震动反馈

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
                // 添加缩放动画
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                node.run(SKAction.sequence([scaleUp, scaleDown]))
            }
            else if node.name?.hasPrefix("objectButton_") == true {
                let selectedObject = node.name!.replacingOccurrences(of: "objectButton_", with: "")
                selectObject(named: selectedObject)
                
                // 添加缩放动画
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                node.run(SKAction.sequence([scaleUp, scaleDown]))
            }
            else if node.name == "backButton" {
                removeBreakInterface()
                showObjectSelection()
                
                // 添加缩放动画
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                node.run(SKAction.sequence([scaleUp, scaleDown]))
            }
        }
    }
    
    func breakObject() {
        guard let maskNode = maskNode else { return }
        
        // 创建新的破洞
        for _ in 0..<holesPerBreak {
            // 创建一个不规则的破碎形状
            let radius = CGFloat.random(in: holeRadiusRange)
            let numberOfPoints = Int.random(in: 12...18)  // 增加顶点数量
            var points: [CGPoint] = []
            
            // 随机位置（稍微扩大范围）
            let centerX = CGFloat.random(in: -90...90)
            let centerY = CGFloat.random(in: -90...90)
            
            // 生成闪电状的随机多边形顶点
            for i in 0..<numberOfPoints {
                let angle = (CGFloat(i) * 2.0 * .pi) / CGFloat(numberOfPoints)
                // 使用不同的随机范围创造更不规则的形状
                let randomRadius = radius * CGFloat.random(in: 0.3...1.7)
                // 添加锯齿状效果
                let zigzag = CGFloat.random(in: -20...20)
                let x = centerX + randomRadius * cos(angle) + zigzag
                let y = centerY + randomRadius * sin(angle) + zigzag
                points.append(CGPoint(x: x, y: y))
            }
            
            // 添加额外的锯齿点，使形状更像闪电
            var extraPoints: [CGPoint] = []
            for i in 0..<points.count {
                let current = points[i]
                let next = points[(i + 1) % points.count]
                
                // 在两点之间添加1-2个额外的锯齿点
                let numberOfExtra = Int.random(in: 1...2)
                for _ in 0..<numberOfExtra {
                    let progress = CGFloat.random(in: 0.2...0.8)
                    let midX = current.x + (next.x - current.x) * progress
                    let midY = current.y + (next.y - current.y) * progress
                    
                    // 添加随机偏移创造锯齿
                    let offset = CGFloat.random(in: -15...15)
                    let perpX = -(next.y - current.y) * offset / 100
                    let perpY = (next.x - current.x) * offset / 100
                    
                    extraPoints.append(CGPoint(x: midX + perpX, y: midY + perpY))
                }
            }
            
            // 将额外的点插入到原始点数组中
            points.append(contentsOf: extraPoints)
            
            // 创建路径
            let path = CGMutablePath()
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            path.closeSubpath()
            
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
}

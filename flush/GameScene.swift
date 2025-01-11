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
    let holesPerBreak = 3
    let holeRadiusRange: ClosedRange<CGFloat> = 10...30
    
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
        guard let cropNode = cropNode, let maskNode = maskNode else { return }
        
        // 增加洞的数量
        currentHoleCount += holesPerBreak
        
        // 生成新的遮罩图像
        let maskImage = generateRandomMask(size: size, holeCount: currentHoleCount, holeRadiusRange: holeRadiusRange)
        maskNode.texture = SKTexture(image: maskImage)
        
        // 重新设置 maskNode 的大小
        maskNode.size = size
        
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 可选：添加粒子效果
        if let explosion = SKEmitterNode(fileNamed: "Explosion.sks") {
            explosion.position = objectNode.position
            explosion.zPosition = 15 // 确保粒子效果在物体之上
            addChild(explosion)
            
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
        
        // 创建 CropNode
        cropNode = SKCropNode()
        cropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        cropNode.zPosition = 5
        
        // 创建 maskNode
        let initialMaskImage = generateRandomMask(size: size, holeCount: 0, holeRadiusRange: holeRadiusRange) // 初始无洞
        maskNode = SKSpriteNode(texture: SKTexture(image: initialMaskImage))
        maskNode.size = size
        maskNode.position = CGPoint(x: 0, y: 0)
        
        cropNode.maskNode = maskNode
        
        // 添加 CropNode 到场景
        addChild(cropNode)
        
        // 添加物体节点到 CropNode
        objectNode = SKSpriteNode(imageNamed: objectName) // 使用用户选择的物体图片
        objectNode.position = CGPoint(x: 0, y: 0) // 相对于 CropNode
        cropNode.addChild(objectNode)
        
        // 添加“打破”按钮
        let breakButton = SKLabelNode(text: "打破")
        breakButton.name = "breakButton"
        breakButton.fontSize = 24
        breakButton.fontColor = .red
        breakButton.position = CGPoint(x: size.width / 2, y: 50)
        breakButton.zPosition = 100 // 确保高于 CropNode
        addChild(breakButton)
        
        // 添加“返回”按钮
        let backButton = SKLabelNode(text: "返回")
        backButton.name = "backButton"
        backButton.fontSize = 20
        backButton.fontColor = .blue
        backButton.position = CGPoint(x: 50, y: size.height - 50)
        backButton.zPosition = 100 // 确保高于 CropNode
        addChild(backButton)
        
        // 创建“打破”按钮背景
        let breakButtonBackground = SKSpriteNode(color: UIColor.red.withAlphaComponent(0.5), size: CGSize(width: 100, height: 50))
        breakButtonBackground.position = breakButton.position
        breakButtonBackground.zPosition = 99 // 背景低于文字
        breakButtonBackground.name = "breakButtonBackground"
        addChild(breakButtonBackground)
        
        // 添加“打破”文字
        let breakButtonLabel = SKLabelNode(text: "打破")
        breakButtonLabel.fontSize = 24
        breakButtonLabel.fontColor = .white
        breakButtonLabel.position = CGPoint.zero
        breakButtonBackground.addChild(breakButtonLabel)
        
        // 同样方式创建“返回”按钮
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
        if let objectNode = objectNode {
            objectNode.removeFromParent()
        }
        
        // 移除 CropNode
        if let cropNode = cropNode {
            cropNode.removeFromParent()
        }
        
        maskNode = nil
        cropNode = nil
        
        // 移除“打破”按钮
        if let breakButton = childNode(withName: "breakButton") {
            breakButton.removeFromParent()
        }
        
        // 移除“返回”按钮
        if let backButton = childNode(withName: "backButton") {
            backButton.removeFromParent()
        }
    }
    
    // 生成随机遮罩
    func generateRandomMask(size: CGSize, holeCount: Int, holeRadiusRange: ClosedRange<CGFloat>) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            // 填充白色（表示可见部分）
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // 绘制黑色洞（表示隐藏部分）
            for _ in 0..<holeCount {
                let radius = CGFloat.random(in: holeRadiusRange)
                let x = CGFloat.random(in: radius...(size.width - radius))
                let y = CGFloat.random(in: radius...(size.height - radius))
                let holeRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                UIColor.black.setFill()
                ctx.cgContext.fillEllipse(in: holeRect)
            }
        }
        return img
    }
}

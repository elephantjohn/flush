//
//  GameScene.swift
//  flush
//
//  Created by 孙韬奋 on 2025/1/11.
//

import SpriteKit
import GameplayKit
import UIKit  // 引入 UIKit 用于震动反馈

class GameScene: SKScene {
    
    // 添加物体节点
    var objectNode: SKSpriteNode!
    
    // 添加物体选择相关节点
    var selectionBackground: SKSpriteNode!
    var objectButtons: [SKSpriteNode] = []
    let availableObjects = ["bottle", "chair", "woman", "man"] // 物体名称数组，确保这些图片已添加到 Assets.xcassets
    
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
            }
            else if node.name?.hasPrefix("objectButton_") == true {
                let selectedObject = node.name!.replacingOccurrences(of: "objectButton_", with: "")
                selectObject(named: selectedObject)
            }
        }
    }
    
    func breakObject() {
        // 物体减少部分
        let scaleAction = SKAction.scale(by: 0.9, duration: 0.2) // 物体减少10%
        objectNode.run(scaleAction)
        
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 破碎动画（示例）
        if let explosion = SKEmitterNode(fileNamed: "Explosion.sks") {
            explosion.position = objectNode.position
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
        
        // 创建物体选择按钮
        let buttonSize = CGSize(width: 80, height: 80)
        let padding: CGFloat = 20
        let totalWidth = CGFloat(availableObjects.count) * (buttonSize.width + padding) - padding
        let startX = (size.width - totalWidth) / 2 + buttonSize.width / 2
        let yPosition = size.height / 2
        
        for (index, objectName) in availableObjects.enumerated() {
            let button = SKSpriteNode(imageNamed: "\(objectName)_icon") // 确保这些图标已添加到 Assets.xcassets
            button.name = "objectButton_\(objectName)"
            button.size = buttonSize
            button.position = CGPoint(x: startX + CGFloat(index) * (buttonSize.width + padding), y: yPosition)
            button.zPosition = 11
            addChild(button)
            objectButtons.append(button)
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
        
        // 添加物体节点
        objectNode = SKSpriteNode(imageNamed: objectName) // 使用用户选择的物体图片
        objectNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(objectNode)
        
        // 添加打破按钮
        let breakButton = SKLabelNode(text: "打破")
        breakButton.name = "breakButton"
        breakButton.fontSize = 24
        breakButton.fontColor = .red
        breakButton.position = CGPoint(x: size.width / 2, y: 50)
        addChild(breakButton)
    }
}

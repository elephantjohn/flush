//
//  GameViewController.swift
//  flush
//
//  Created by 孙韬奋 on 2025/1/11.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as! SKView? {
            // 创建并加载 GameScene
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            
            // 显示FPS和节点计数（可选）
            view.showsFPS = true
            view.showsNodeCount = true
            
            // 呈现场景
            view.presentScene(scene)
        }
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

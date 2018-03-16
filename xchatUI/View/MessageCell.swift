//
//  MessageCell.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class MessageCell: UITableViewCell {
    
    @IBOutlet weak var labelMessage: UILabel!
    @IBOutlet weak var labelDate: UILabel!
    @IBOutlet weak var viewMessage: UIView!
    
    override func layoutSubviews() {
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        labelMessage.addGestureRecognizer(gestureRecognizer)
    }
    func handleLongPressGesture(recognizer: UIGestureRecognizer) {
        guard recognizer.state == .recognized else { return }
        
        if let recognizerView = recognizer.view,
            let recognizerSuperView = recognizerView.superview,
            recognizerView.becomeFirstResponder()
        {
            let menuController = UIMenuController.shared
            menuController.setTargetRect(recognizerView.frame, in: recognizerSuperView)
            menuController.setMenuVisible(true, animated:true)
        }
    }
    
}

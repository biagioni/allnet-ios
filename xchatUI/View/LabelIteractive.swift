//
//  LabelIteractive.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 3/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//
import UIKit

class LabelInteractive: UILabel {
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        self.backgroundColor = UIColor(hex: "EEEEEE")
        return (action == #selector(UIResponderStandardEditActions.copy(_:)))
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
        self.backgroundColor = UIColor.white
    }
}

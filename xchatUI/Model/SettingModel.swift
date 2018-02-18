//
//  SettingModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/18/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

struct SettingModel {
    var name: String
    var icon: UIImage
    var isSelected: Bool
    var backGroundColor: UIColor
    
    init(name: String, icon: UIImage, isSelected: Bool, backGroundColor: UIColor) {
        self.name = name
        self.icon = icon
        self.isSelected = isSelected
        self.backGroundColor = backGroundColor
    }
}

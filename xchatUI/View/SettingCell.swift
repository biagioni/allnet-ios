//
//  SettingCell.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/18/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class SettingCell: UITableViewCell {
    @IBOutlet weak var labelName: UILabel!
    @IBOutlet weak var switchValue: UISwitch!
    @IBOutlet weak var imageViewIcon: UIImageView!
    @IBOutlet weak var viewBackground: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    func update(with item: SettingModel){
        labelName.text = item.name
        switchValue.isOn = item.isSelected
        imageViewIcon.image = item.icon
        viewBackground.backgroundColor = item.backGroundColor
    }
}

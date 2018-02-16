//
//  ContactCell.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/15/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class ContactCell: UITableViewCell {
    @IBOutlet weak var labelName: UILabel!
    @IBOutlet weak var labelDate: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    func update(with item:(String, String)){
        labelName.text = item.0
        labelDate.text = item.1
    }
}

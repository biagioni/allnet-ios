//
//  TextFieldCell.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/19/18.
//  Copyright © 2018 allnet. All rights reserved.
//


class TextFieldCell: UITableViewCell {
    @IBOutlet weak var labelName: UILabel!
    @IBOutlet weak var textFieldName: UITextField!
    
    func update(with item: (String, String)){
        labelName.text = item.0
        textFieldName.text = item.1
    }
}

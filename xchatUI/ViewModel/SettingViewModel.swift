//
//  SettingViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/18/18.
//  Copyright © 2018 allnet. All rights reserved.
//

class SettingViewModel {
    var switches: [SettingModel]
    var deletes: [(String, String)]
    var fields: [(String, String)]
    private var _contact: String
    
    init(contact: String) {
        switches = [SettingModel]()
        _contact = contact
        deletes = [(String, String)]()
        fields = [(String, String)]()
        populate()
    }
    
    var isVisible: Bool {
        return is_invisible(_contact) == 0
    }
    
    func populate(){
        deletes.removeAll()
        switches.removeAll()
        fields.removeAll()
        
        fields.append(("Name", _contact))
        
        deletes.append(("Delete conversation", " MB"))
        deletes.append(("Delete user", ""))
        
        switches.append(SettingModel(name: "Visible", icon: UIImage(named: "eye")!, isSelected: isVisible, backGroundColor: UIColor(hex: "155AA7")))
        switches.append(SettingModel(name: "Notification", icon: UIImage(named: "notification")!, isSelected: false, backGroundColor: UIColor(hex: "B44D62")))
        switches.append(SettingModel(name: "Save Messages", icon: UIImage(named: "save")!, isSelected: true, backGroundColor: UIColor(hex: "12A76F")))
    }
    
    func setValue(forIndex index: Int, value: Bool){
        switches[index].isSelected = value
    }
    func setValue(forIndex index: Int, value: String?){
        if let message = value, message.count > 0 {
            fields[index].1 = message
        }
    }
    
    func deleteConversation(){
        delete_conversation(_contact)
    }
    
    func deleteContact(){
        delete_contact(_contact)
    }
    
    func saveSettings(){
        if switches[0].isSelected != isVisible {
            if switches[0].isSelected {
                make_visible(_contact)
            }else{
                make_invisible(_contact)
            }
        }
        if fields[0].1 != _contact {
            rename_contact(_contact, fields[0].1)
        }
    }
}

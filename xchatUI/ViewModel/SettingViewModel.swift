//
//  SettingViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/18/18.
//  Copyright © 2018 allnet. All rights reserved.
//

class SettingViewModel {
    private var _list: [SettingModel]
    
    init() {
        _list = [SettingModel]()
        populate()
    }
    
    subscript(index: Int) -> SettingModel {
        return _list[index]
    }
    
    var count: Int {
        return _list.count
    }
    
    func populate(){
        _list.append(SettingModel(name: "Visible", icon: UIImage(named: "eye")!, isSelected: false, backGroundColor: UIColor(hex: "155AA7")))
        _list.append(SettingModel(name: "Notification", icon: UIImage(named: "notification")!, isSelected: false, backGroundColor: UIColor(hex: "B44D62")))
        _list.append(SettingModel(name: "Save Messages", icon: UIImage(named: "save")!, isSelected: true, backGroundColor: UIColor(hex: "12A76F")))
    }
}

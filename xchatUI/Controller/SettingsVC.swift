//
//  SettingsVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/18/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class SettingsVC: UIViewController {

    var settingVM: SettingViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        settingVM = SettingViewModel()
    }
}

extension SettingsVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingVM.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath) as! SettingCell
        cell.update(with: settingVM[indexPath.row])
        return cell
    }
}

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
    var deletes: [(String, String)]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deletes = [(String, String)]()
        deletes.append(("Delete conversation", "-"))
        deletes.append(("Delete user", ""))
        settingVM = SettingViewModel()
    }
}

extension SettingsVC: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return settingVM.count
        }else{
            return deletes.count
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath) as! SettingCell
            cell.update(with: settingVM[indexPath.row])
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "DeleteCell", for: indexPath) as! DeleteCell
            cell.update(with: deletes[indexPath.row])
            return cell
        }
    }
}

extension SettingsVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1{
            return 50
        }
        return 0
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let label = UILabel()
            label.text = "  Can't be undone"
            label.font = UIFont(name: "Avenir", size: 16)
            label.backgroundColor = UIColor(hex: "EEEEEE")
            return label
        }
        return nil
    }
}

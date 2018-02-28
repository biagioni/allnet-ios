//
//  SettingsVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/18/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class SettingsVC: UITableViewController {

    
    @IBOutlet weak var textFieldName: UITextField!
    @IBOutlet weak var switchVisible: UISwitch!
    @IBOutlet weak var switchNotification: UISwitch!
    @IBOutlet weak var switchSaveMessages: UISwitch!
    
    var settingVM: SettingViewModel!
    var messageVM: MessageViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingVM = SettingViewModel(contact: messageVM.selectedContact!)
        settingVM.deletes[0].1 = messageVM.messageSize+" MB"
    }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    @IBAction func deleteConversation(_ sender: UIButton) {
    }
    @IBAction func deleteUser(_ sender: UIButton) {
    }
    
}

//extension SettingsVC: UITableViewDataSource {
//    func numberOfSections(in tableView: UITableView) -> Int {
//        return 3
//    }
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        if section == 0 {
//            return settingVM.fields.count
//        }else if section == 1 {
//            return settingVM.switches.count
//        }else if section == 2 {
//            return settingVM.deletes.count
//        }
//        return 0
//    }
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        if indexPath.section == 0 {
//            let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextFieldCell
//            cell.update(with: settingVM.fields[indexPath.row])
//            cell.textFieldName.tag = indexPath.row
//            return cell
//        }
//        if indexPath.section == 1 {
//            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath) as! SettingCell
//            cell.update(with: settingVM.switches[indexPath.row])
//            cell.switchValue.tag = indexPath.row
//            return cell
//        }else{
//            let cell = tableView.dequeueReusableCell(withIdentifier: "DeleteCell", for: indexPath) as! DeleteCell
//            cell.update(with: settingVM.deletes[indexPath.row])
//            return cell
//        }
//    }
//}

extension SettingsVC: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        settingVM.setValue(forIndex: textField.tag, value: textField.text)
        textField.text = settingVM.fields[textField.tag].1
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

//extension SettingsVC: UITableViewDelegate {
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true)
//        if indexPath.section == 2 {
//            if indexPath.row == 0 {
//                let alert = UIAlertController(title: nil, message: "Are you sure you want to delete the conversation?", preferredStyle: .alert)
//                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//                let delete = UIAlertAction(title: "Delete", style: .destructive){
//                    action in
//                    self.settingVM.deleteConversation()
//                }
//                alert.addAction(cancel)
//                alert.addAction(delete)
//                self.present(alert, animated: true)
//            }else if indexPath.row == 1 {
//                let alert = UIAlertController(title: nil, message: "Are you sure you want to delete the contact?", preferredStyle: .alert)
//                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//                let delete = UIAlertAction(title: "Delete", style: .destructive){
//                    action in
//                    self.settingVM.deleteContact()
//                    self.navigationController?.popViewController(animated: true)
//                }
//                alert.addAction(cancel)
//                alert.addAction(delete)
//                self.present(alert, animated: true)
//            }
//        }
//    }



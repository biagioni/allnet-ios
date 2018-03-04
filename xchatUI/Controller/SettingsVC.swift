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
    @IBOutlet weak var labelConversationSize: UILabel!
    @IBOutlet weak var buttonGroup: UIButton!
    
    
    var messageVM: MessageViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if messageVM.isGroup() {
            buttonGroup.setTitle("    Manage participants", for: .normal)
        }else{
            buttonGroup.setTitle("    Manage groups", for: .normal)
        }
        updateUI()
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    @IBAction func save(_ sender: UIBarButtonItem) {
        let contact = messageVM.selectedContact
        if switchVisible.isOn {
            make_visible(contact)
        }else{
            make_invisible(contact)
        }
        if contact != textFieldName.text {
            rename_contact(contact, textFieldName.text)
        }
    }
    @IBAction func manageParticipants(_ sender: Any) {
    }
    @IBAction func copyConversation(_ sender: Any) {
    }
    
    @IBAction func deleteConversation(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: "Are you sure you want to delete the conversation?", preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let delete = UIAlertAction(title: "Delete", style: .destructive){
            [weak self] action in
            delete_conversation(self?.messageVM.selectedContact!)
        }
        alert.addAction(cancel)
        alert.addAction(delete)
        self.present(alert, animated: true)
    }
    
    @IBAction func deleteUser(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: "Are you sure you want to delete the contact?", preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let delete = UIAlertAction(title: "Delete", style: .destructive){
           [weak self] action in
            delete_contact(self?.messageVM.selectedContact!)
            self?.navigationController?.popViewController(animated: true)
        }
        alert.addAction(cancel)
        alert.addAction(delete)
        self.present(alert, animated: true)
    }
    
    func updateUI(){
        textFieldName.text = messageVM.selectedContact
        labelConversationSize.text = messageVM.messageSize+" MB"
        switchVisible.isOn = is_invisible(messageVM.selectedContact!) == 0
        switchSaveMessages.isOn = switchVisible.isOn
        switchNotification.isOn = switchVisible.isOn
    }
}

extension SettingsVC: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text!.isEmpty {
            textField.text = messageVM.selectedContact
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

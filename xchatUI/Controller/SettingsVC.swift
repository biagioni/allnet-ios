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
    @IBOutlet weak var buttonDelete: UIButton!
    
    
    var contactVM: ContactViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if contactVM.isGroup(nil) {
            buttonGroup.setTitle("    Manage participants", for: .normal)
            buttonDelete.setTitle("    Delete group", for: .normal)
        }else{
            buttonGroup.setTitle("    Manage groups", for: .normal)
            buttonDelete.setTitle("    Delete user", for: .normal)
        }
        updateUI()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showGroups" {
            let destination = segue.destination as! GroupVC
            destination.contactVM = contactVM
            destination.isGroup = sender as! Bool
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    @IBAction func save(_ sender: UIBarButtonItem) {
        let contact = contactVM.selectedContact
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
        if contactVM.isGroup(nil) {
            self.performSegue(withIdentifier: "showGroups", sender: true)
        }else{
            self.performSegue(withIdentifier: "showGroups", sender: false)
        }
    }
    
    @IBAction func deleteConversation(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: "Are you sure you want to delete the conversation?", preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let delete = UIAlertAction(title: "Delete", style: .destructive){
            [weak self] action in
            delete_conversation(self?.contactVM.selectedContact!)
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
            delete_contact(self?.contactVM.selectedContact!)
            self?.navigationController?.popViewController(animated: true)
        }
        alert.addAction(cancel)
        alert.addAction(delete)
        self.present(alert, animated: true)
    }
    
    func updateUI(){
        textFieldName.text = contactVM.selectedContact
        labelConversationSize.text = contactVM.messageSize+" MB"
        switchVisible.isOn = is_invisible(contactVM.selectedContact!) == 0
        switchSaveMessages.isOn = switchVisible.isOn
        switchNotification.isOn = switchVisible.isOn
    }
}

extension SettingsVC: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text!.isEmpty {
            textField.text = contactVM.selectedContact
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

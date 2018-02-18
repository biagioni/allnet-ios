//
//  ContactListVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

@objc class ContactListVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var buttonEdit: UIBarButtonItem!
    
    var contactVM: ContactViewModel!
    var messageVM: MessageViewModel!
    var sectionsCount = 1
    var displaySettings: Bool!
    var unreadMessages: [String]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.setXChatValue(XChat())
        appDelegate.xChat.initialize()
        
        messageVM = MessageViewModel()
        messageVM.contactDelegate = self
        appDelegate.xChat.setMessageVM(messageVM)

        contactVM = ContactViewModel()
        contactVM.delegate = self
        contactVM.fetchData()
        
        unreadMessages = [String]()
        navigationItem.title = "\(contactVM.count) Contact(s)"
        displaySettings = false
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //labelCountContacts.text = unreadMessages.count.description
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMessage"{
            let selectedContact = sender as! String
            unreadMessages = unreadMessages.filter{$0 != selectedContact}
            
            let destination = segue.destination as! MessageVC
            destination.contact = selectedContact
            destination.messageVM = messageVM
        }
    }
    
    @IBAction func showHidden(_ sender: UIBarButtonItem) {
        displaySettings = !displaySettings
        var button: UIBarButtonItem!
        if displaySettings {
            sectionsCount = 2
            button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(showHidden))
        }else{
            sectionsCount = 1
            button = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(showHidden))
        }
        navigationItem.setRightBarButton(button, animated: true)
    
        tableView.reloadData()
    }
    
    func loadData(){
        contactVM.fetchData()
        self.navigationItem.title = "\(contactVM.count) Contact(s)"
    }
    func updateNotification(contact: String, cell: ContactCell){
        if unreadMessages.contains(contact){
            cell.labelNotification.isHidden = false
            let count = unreadMessages.filter({$0 == contact}).count
            cell.labelNotification.text = count.description
        }else{
            cell.labelNotification.isHidden = true
        }
    }
}

extension ContactListVC: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionsCount
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return contactVM.count
        }else{
            return contactVM.hiddenCount
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell
        if indexPath.section == 0 {
            if let item = contactVM[indexPath.row] {
                updateNotification(contact: item.0, cell: cell)
                cell.update(with: item)
            }
        }else{
            if let item = contactVM.hidden(index: indexPath.row) {
                updateNotification(contact: item.0, cell: cell)
                cell.update(with: item)
            }
        }
        
        if displaySettings {
            cell.imageViewSettings.isHidden = false
        }else{
            cell.imageViewSettings.isHidden = true
        }
        return cell
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return " Visible Contacts"
        }else{
            return " Hidden Contacts"
        }
    }
}

extension ContactListVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if displaySettings {
            self.performSegue(withIdentifier: "showSettings", sender: contactVM[indexPath.row]!.0)
        }else{
            self.performSegue(withIdentifier: "showMessage", sender: contactVM[indexPath.row]!.0)
        }
    }
}

extension ContactListVC: ContactDelegate {
    func newMessageReceived(fromContact contact: String) {
        unreadMessages.append(contact)
        if let index = contactVM.indexOf(contact: contact) {
            contactVM.setTimeForNewMessage(index: index)
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    func contactUpdated() {
        tableView.reloadData()
    }
}


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
    @IBOutlet weak var labelCountContacts: UILabel!
    
    var contactVM: ContactViewModel!
    var sectionsCount = 1
    var displaySettings: Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.setXChatValue(XChat())
        appDelegate.xChat.initialize()
        
        contactVM = ContactViewModel()
        contactVM.delegate = self
        contactVM.fetchData()
        navigationItem.title = "\(contactVM.count) Contacts"
        displaySettings = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMessage"{
            let destination = segue.destination as! MessageVC
            destination.contact = sender as! String
            destination.delegate = self
        }
    }
    
    @IBAction func showHidden(_ sender: UIBarButtonItem) {
        displaySettings = !displaySettings
        if displaySettings {
            sectionsCount = 2
        }else{
            sectionsCount = 1
        }
        tableView.reloadData()
    }
    
    func loadData(){
        contactVM.fetchData()
        self.navigationItem.title = "\(contactVM.count) Contact(s)"
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
                cell.update(with: item)
            }
        }else{
            if let item = contactVM.hidden(index: indexPath.row) {
                cell.update(with: item)
            }
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
            
        }else{
            self.performSegue(withIdentifier: "showMessage", sender: contactVM[indexPath.row]!.0)
        }
    }
}

extension ContactListVC: ContactDelegate {
    func contactUpdated() {
        tableView.reloadData()
    }
}

extension ContactListVC: MessageViewDelegate {
    func newMessage(fromContact contact: String) {
        print("NEWWWWWWWWWWWWWWWWWW")
    }
}


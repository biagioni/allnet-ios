//
//  GroupVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 3/4/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class GroupVC: UITableViewController {
    
    var contactVM: ContactViewModel!
    var isGroup: Bool!

    override func viewDidLoad() {
        super.viewDidLoad()
        if isGroup {
            contactVM.loadMembers()
            navigationItem.title = "Participants"
        }else{
            contactVM.loadGroups()
            navigationItem.title = "Groups"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactVM.groupsCount
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath)
        cell.textLabel?.text = contactVM.groups(index: indexPath.row)?.0
        if let value = contactVM.groups(index: indexPath.row)?.1, value {
            cell.accessoryType = .checkmark
        }else{
            cell.accessoryType = .none

        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if isGroup {
            if tableView.cellForRow(at: indexPath)?.accessoryType == .checkmark {
                remove_from_group(contactVM.selectedContact, contactVM.groups(index: indexPath.row)?.0)
            }else{
                add_to_group(contactVM.selectedContact, contactVM.groups(index: indexPath.row)?.0)
            }
        }else{
            if tableView.cellForRow(at: indexPath)?.accessoryType == .checkmark {
                remove_from_group(contactVM.groups(index: indexPath.row)?.0, contactVM.selectedContact)
            }else{
                add_to_group(contactVM.groups(index: indexPath.row)?.0, contactVM.selectedContact)
            }
        }
        if isGroup {
            contactVM.loadMembers()
        }else{
            contactVM.loadGroups()
        }
        tableView.reloadData()
    }
}

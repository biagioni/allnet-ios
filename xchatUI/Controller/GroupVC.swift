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
        }else{
            contactVM.loadGroups()
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
}

//
//  ContactListVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/15/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class ContactListVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
}

extension ContactListVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath)
        return cell
    }
}

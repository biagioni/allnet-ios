//
//  ContactNewVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/25/18.
//  Copyright © 2018 allnet. All rights reserved.
//

class ContactNewVC: UIViewController {
    
    @IBOutlet weak var textFieldName: UITextField!
    @IBOutlet weak var textFieldSecret: UITextField!
    @IBOutlet weak var pickerViewConnection: UIPickerView!
    @IBOutlet weak var tableView: UITableView!
    
    var keyVM: KeyViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keyVM = KeyViewModel(contact: "")
        keyVM.fetchIncompletedKeys()
    }
    
}

extension ContactNewVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keyVM.incompleteKeysExchanges.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "KeyCell", for: indexPath)
        cell.textLabel?.text = keyVM.incompleteKeysExchanges[indexPath.row]
        return cell
    }
}

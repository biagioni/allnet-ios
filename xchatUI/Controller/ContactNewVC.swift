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
    @IBOutlet weak var heightTableView: NSLayoutConstraint!
    
    var keyVM: KeyViewModel!
    var connectionValues: [String]!
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        keyVM = KeyViewModel(contact: "")
        keyVM.fetchIncompletedKeys()
        connectionValues = ["regular internet contact", "nearby wireless contact","new group"]
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.removeObserver(self, forKeyPath: "contentSize")
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let obj = object as? UITableView {
            if obj == self.tableView && keyPath == "contentSize" {
                 heightTableView.constant = tableView.contentSize.height
            }
        }
    }
    @IBAction func requestContact(_ sender: UIButton) {
        var hops = 0
        guard let name = textFieldName.text, !name.isEmpty else {
            ///TODO message
            return
        }
        if pickerViewConnection.selectedRow(inComponent: 0) == 0 {
            hops = 6
        } else if pickerViewConnection.selectedRow(inComponent: 0) == 1 {
            hops = 1
        }
        if let key = textFieldSecret.text, key.isEmpty {
            appDelegate.xChat.requestKey(name, maxHops: 10)
        }else{
            //appDelegate.xChat.requestNewContact(name, maxHops: hops, secret1: <#T##String!#>, optionalSecret2: <#T##String!#>, keyExchange: <#T##KeyExchangeUIViewController!#>)
        }
        self.performSegue(withIdentifier: "showKeyExchange", sender: name)
    }
}

extension ContactNewVC: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return connectionValues.count
    }
}

extension ContactNewVC: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return connectionValues[row]
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

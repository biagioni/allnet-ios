//
//  ContactNewVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/25/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class ContactNewVC: UIViewController {
    
    @IBOutlet weak var textFieldName: UITextField!
    @IBOutlet weak var textFieldSecret: UITextField!
    @IBOutlet weak var pickerViewConnection: UIPickerView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var heightTableView: NSLayoutConstraint!
    @IBOutlet weak var labelImcomplete: UILabel!
    @IBOutlet weak var heightPicker: NSLayoutConstraint!
    @IBOutlet weak var buttonSelection: UIButton!
    @IBOutlet weak var requestButton: UIButton!
    
    var keyVM: KeyViewModel!
    var connectionValues: [String]!
    var info: (name: String, key: String?, hops: Int)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // self.navigationController?.view.backgroundColor = UIColor.white
        heightPicker.constant = 0
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        connectionValues = ["regular internet contact", "nearby wireless contact","new group (no secret)"]
    }
    deinit {
        tableView.removeObserver(self, forKeyPath: "contentSize")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyVM = KeyViewModel()
        keyVM.fetchIncompletedKeys()
        tableView.reloadData()
        if keyVM.incompleteKeysExchanges.count > 0 {
            labelImcomplete.isHidden = false
        }else{
            labelImcomplete.isHidden = true
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showKeyExchange" {
            let destination = segue.destination as! KeyExchangeVC
            destination.info = info
            destination.isGroup = (sender as! Bool)
            destination.isExchanged = CHelper.exchange_is_complete(info.name)
            destination.keyVM = keyVM
        }
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let obj = object as? UITableView {
            if obj == self.tableView && keyPath == "contentSize" {
                 heightTableView.constant = tableView.contentSize.height
            }
        }
    }
    

    @IBAction func openPicker(_ sender: Any) {
        if heightPicker.constant == 0 {
            UIView.animate(withDuration: 0.5,
                           animations: {
                            self.heightPicker.constant = 162
                })
            
        }else{
            UIView.animate(withDuration: 0.5,
                           animations: {
                            self.heightPicker.constant = 0
                })
        }
    }
    
    
    @IBAction func requestContact(_ sender: UIButton) {
        var hops = 0
        guard let name = textFieldName.text, !name.isEmpty else {
            ///TODO message
            return
        }
        if pickerViewConnection.selectedRow(inComponent: 0) == 2 { // group
            info = (name, textFieldSecret.text, 0)
            self.performSegue(withIdentifier: "showKeyExchange", sender: true)
        }else{
            if pickerViewConnection.selectedRow(inComponent: 0) == 0 {  // regular internet contact
                hops = 6
            } else if pickerViewConnection.selectedRow(inComponent: 0) == 1 {  // 1-hop contact
                hops = 1
            }
            info = (name, textFieldSecret.text, hops)
            self.performSegue(withIdentifier: "showKeyExchange", sender: false)
        }
        textFieldName.text = ""
        textFieldSecret.text = ""
        pickerViewConnection.selectRow(0, inComponent: 0, animated: true)
        buttonSelection.setTitle(connectionValues[0], for: .normal)
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
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        buttonSelection.setTitle(connectionValues[row], for: .normal)
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

extension ContactNewVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let contact = keyVM.incompleteKeysExchanges[indexPath.row]
        if let key = keyVM.getKeyFor(contact: contact) {
            info = (contact, key, 10)
            self.performSegue(withIdentifier: "showKeyExchange", sender: false)
        }else{
            textFieldName.text = contact
        }
    }
}

extension ContactNewVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == textFieldName {
            textField.resignFirstResponder()
            textFieldSecret.becomeFirstResponder()
        } else if textField == textFieldSecret {
            if (textFieldSecret.text?.count ?? 0) > 0 {
                requestButton.setTitle("Request contact", for: .normal)
            } else {
                requestButton.setTitle("Request contact (and show secret)", for: .normal)
            }
            textFieldSecret.resignFirstResponder()
        }else{
            textField.resignFirstResponder()
        }
        return true
    }
}

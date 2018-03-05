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
    @IBOutlet weak var labelImcomplete: UILabel!
    @IBOutlet weak var heightPicker: NSLayoutConstraint!
    @IBOutlet weak var buttonSelection: UIButton!
    
    var keyVM: KeyViewModel!
    var connectionValues: [String]!
    var info: (name: String, key: String?, hops: Int)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        heightPicker.constant = 0
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        keyVM = KeyViewModel(contact: "")
        keyVM.fetchIncompletedKeys()
        connectionValues = ["regular internet contact", "nearby wireless contact","new group"]
        if keyVM.incompleteKeysExchanges.count > 0 {
            labelImcomplete.isHidden = false
        }else{
            labelImcomplete.isHidden = true
        }
    }
    deinit {
        tableView.removeObserver(self, forKeyPath: "contentSize")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyVM.fetchIncompletedKeys()
        tableView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showKeyExchange" {
            let destination = segue.destination as! KeyExchangeVC
            destination.info = info
            destination.isGroup = sender as! Bool
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
        if pickerViewConnection.selectedRow(inComponent: 0) == 2 {
            info = (name, textFieldSecret.text, 10)
            self.performSegue(withIdentifier: "showKeyExchange", sender: true)
        }else{
            if pickerViewConnection.selectedRow(inComponent: 0) == 0 {
                hops = 6
            } else if pickerViewConnection.selectedRow(inComponent: 0) == 1 {
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
        let key = keyVM.getKeyFor(contact: contact)
        
        textFieldSecret.text = key
        textFieldName.text = contact
    }
}

extension ContactNewVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == textFieldName {
            textField.resignFirstResponder()
            textFieldSecret.becomeFirstResponder()
        }else{
            textField.resignFirstResponder()
        }
        return true
    }
}

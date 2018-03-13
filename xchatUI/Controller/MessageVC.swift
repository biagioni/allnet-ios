//
//  MessageVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

protocol MessageViewDelegate {
    func newMessage(fromContact contact: String)
}

class MessageVC: UIViewController {

    @IBOutlet weak var textFieldMessage: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageHeight: NSLayoutConstraint!
    
    var messageVM: MessageViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.view.backgroundColor = UIColor.white
        navigationItem.title = messageVM.selectedContact
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52
        
        let tap  = UITapGestureRecognizer(target: self, action: #selector(closeKeyboard))
        tableView.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        messageVM.fetchData()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageVM.removeContact()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
        guard let message = textFieldMessage.text, message.count > 0 else {
            return
        }
        messageVM.sendMessage(message: message)
        textFieldMessage.text = ""
    }
    
    func closeKeyboard(){
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            messageHeight.constant += keyboardSize.height
        }
    }
    func keyboardDidShow(notification: NSNotification) {
        if self.messageVM.count > 0 {
            let indexPath = IndexPath(row: self.messageVM.count-1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            messageHeight.constant -= keyboardSize.height
        }
    }
}

extension MessageVC: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageVM.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var identifier = ""
        if let item = messageVM[indexPath.row] {
            if item.msg_type == MSG_TYPE_SENT {
                identifier = "MessageCellSent"
            }else{
                identifier = "MessageCellReceived"
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MessageCell
            cell.labelMessage.text = item.message
            cell.labelDate.text = item.dated
            if item.message_has_been_acked == 0 {
                if item.msg_type != MSG_TYPE_RCVD {
                    cell.viewMessage.backgroundColor = UIColor(hex: "FFD8E5")
                }
            }else{
                cell.viewMessage.backgroundColor = UIColor(hex: "E2F9CB")
            }
            return cell
        }
        
        return UITableViewCell()
    }
}

extension MessageVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension MessageVC: MessageDelegate {
    
    func ackMessages(forIndexes indexes: [Int]) {
        if tableView != nil {
            DispatchQueue.main.async {
                let indexPaths = indexes.map{IndexPath(item: $0, section: 0)}
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: indexPaths, with: .automatic)
                self.tableView.endUpdates()
            }
        }
    }
    
    func addedNewMessage(index: Int) {
        if tableView != nil {
            DispatchQueue.main.async {
                let indexPath = IndexPath(item: index, section: 0)
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: [indexPath], with: .automatic)
                self.tableView.endUpdates()
                self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
            }
        }
    }
    
    func messagesUpdated() {
        if tableView != nil {
            DispatchQueue.main.async {
                self.tableView.reloadData()
                if self.messageVM.count > 0 {
                    let indexPath = IndexPath(row: self.messageVM.count-1, section: 0)
                    self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
                }
            }
        }
    }
}

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

    var messageVM: MessageViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = messageVM.selectedContact
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52
        messageVM.fetchData()
        
        let tap  = UITapGestureRecognizer(target: self, action: #selector(closeKeyboard))
        tableView.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageVM.removeContact()
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
        closeKeyboard()
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
            self.view.frame.origin.y -= keyboardSize.height
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            self.view.frame.origin.y += keyboardSize.height
        }
    }
    

//
//    func notifyConversationChange(beingDisplayed: Bool){
//        cHelper.notifyConversationChange(beingDisplayed, conversationIsDisplayed, conversation, self, tableView, contactsWithNewMessages)
//    }
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
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MessageCell
        cell.labelMessage.text = messageVM[indexPath.row]?.message
        cell.labelDate.text = messageVM[indexPath.row]?.dated
        return cell
    }
}

extension MessageVC: MessageDelegate {
    func messagesUpdated() {
        if tableView != nil {
            tableView.reloadData()
            DispatchQueue.main.async {
                if self.messageVM.count > 0 {
                    let indexPath = IndexPath(row: self.messageVM.count-1, section: 0)
                    self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
                }
            }
        }
    }
}

//
//  MessageVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class MessageVC: UIViewController {

    @IBOutlet weak var textFieldMessage: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
       // self.xchat.initialize(conversation, contacts: self, vc: mayCreateNewContact, mvc: more)
       // self.conversation?.initialize(xchat.getSocket(), messageField: message, send: sendButton, contact: initialLatestContact as! String, decorativeLabel: nMessageLabel)
        let tap  = UITapGestureRecognizer(target: self, action: #selector(closeKeyboard))
        tableView.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
        closeKeyboard()
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
    
//    func reIniSocket() {
//        conversation?.setSocket(xchat.getSocket())
//    }
//    
//    func newMessage(contact: String){
//        cHelper.newMessage(contact, message, conversationIsDisplayed, contactsWithNewMessages, self, tableView)
//    }
//    
//    func notifyConversationChange(beingDisplayed: Bool){
//        cHelper.notifyConversationChange(beingDisplayed, conversationIsDisplayed, conversation, self, tableView, contactsWithNewMessages)
//    }
}

extension MessageVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        return cell
    }
}

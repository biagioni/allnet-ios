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

    @IBOutlet weak var textViewMessage: UITextView!
    @IBOutlet weak var heightMessage: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var viewMessage: UIView!
    
    var messageVM: MessageViewModel!
    let MESSAGE_INITIAL_SIZE: CGFloat = 44
    let MESSAGING_PADDING: CGFloat = 16
    var keyboardHeight:CGFloat = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        self.navigationController?.view.backgroundColor = UIColor.white
        navigationItem.title = messageVM.selectedContact
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }
    
    override var inputAccessoryView: UIView? {
        return viewMessage
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        messageVM.fetchData()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageVM.removeContact()
        self.view.endEditing(true)
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
        guard let message = textViewMessage.text, message.count > 0 else {
            return
        }
        messageVM.sendMessage(message: message)
        let valueIncreasedOnTextView = textViewMessage.frame.height - MESSAGE_INITIAL_SIZE
        textViewMessage.text = ""
        self.keyboardHeight -= valueIncreasedOnTextView
        checkKeyboard(textView: textViewMessage)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            UIView.animate(withDuration: 0.4, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                self.keyboardHeight = keyboardSize.height
                self.checkKeyboard(textView: self.textViewMessage)
                }, completion: {_ in
                    if self.keyboardHeight > 60 {
                        if self.messageVM.count > 0 {
                            let indexPath = IndexPath(row: self.messageVM.count-1, section: 0)
                            self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
                        }
                    }
            })
        }
    }
    
    func checkKeyboard(textView: UITextView){
        if textView.contentSize.height > MESSAGE_INITIAL_SIZE {
            heightMessage.constant = textView.contentSize.height
            for constraint in (inputAccessoryView?.constraints)! {
                if constraint.constant == viewMessage.frame.height {
                    constraint.constant = MESSAGING_PADDING + textView.contentSize.height
                    tableView.contentInset.bottom = keyboardHeight
                }
            }
        }else{
            heightMessage.constant = MESSAGE_INITIAL_SIZE
            for constraint in (inputAccessoryView?.constraints)! {
                if constraint.constant == viewMessage.frame.height {
                    constraint.constant = MESSAGING_PADDING + MESSAGE_INITIAL_SIZE
                    tableView.contentInset.bottom = keyboardHeight
                }
            }
        }
    }
}

extension MessageVC: UITableViewDataSource {
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
            if item.msg_type == MSG_TYPE_RCVD {
                var fractionOfDay:Double = 1
                let SECONDS_PER_DAY: Double = 24 * 60 * 60
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .medium
                let dateMessage = dateFormatter.date(from: item.dated)
                let elapsed = Date().timeIntervalSince(dateMessage!)
                if elapsed < SECONDS_PER_DAY {
                    fractionOfDay = elapsed / SECONDS_PER_DAY
                }
                cell.viewMessage.backgroundColor = UIColor(red: CGFloat(fractionOfDay), green: 1, blue: 1, alpha: 1)
            }else{
                if item.message_has_been_acked == 0 {
                    cell.viewMessage.backgroundColor = UIColor(hex: "FFD8E5")
                }else{
                    cell.viewMessage.backgroundColor = UIColor(hex: "E2F9CB")
                }
            }
            return cell
        }
        
        return UITableViewCell()
    }
}


extension MessageVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        checkKeyboard(textView: textView)
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

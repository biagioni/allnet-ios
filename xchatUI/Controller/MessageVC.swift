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
        
        self.navigationController?.view.backgroundColor = UIColor.white
        navigationItem.title = messageVM.selectedContact
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override var inputAccessoryView: UIView? {
        return viewMessage
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
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
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            UIView.animate(withDuration: 0.4, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                self.keyboardHeight = keyboardSize.height
                self.checkKeyboard(textView: self.textViewMessage)
                }, completion: {_ in
                    if self.keyboardHeight > 60 {
                        if self.messageVM.count > 0 {
                            let indexPath = IndexPath(row: self.messageVM.count-1, section: 0)
                            self.tableView.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.bottom, animated: true)
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
            if (item.contact_name != nil) &&
                (item.contact_name.lengthOfBytes(using: String.Encoding.utf8) > 0) {
                let toFrom = (item.msg_type == MSG_TYPE_RCVD) ? "from" : "to"
                cell.labelDate.text = toFrom + " " + item.contact_name + ", " + item.dated
            }
            if item.msg_type == MSG_TYPE_RCVD {
                var fractionOfDay:Double = 1
                let SECONDS_PER_DAY: Double = 24 * 60 * 60
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .medium
                // let dateMessage = dateFormatter.date(from: item.dated)
                let receivedMessage = ((item.received == nil) ? dateFormatter.date(from: item.dated) : dateFormatter.date(from: item.received))
                let elapsed = Date().timeIntervalSince(receivedMessage!)
                if elapsed < SECONDS_PER_DAY {
                    fractionOfDay = elapsed / SECONDS_PER_DAY
                }
                cell.viewMessage.backgroundColor = UIColor(red: CGFloat(fractionOfDay), green: 1, blue: 1, alpha: 1)
            }else if item.msg_type == MSG_MISSED {
                cell.viewMessage.backgroundColor = UIColor.red
            }else{
                if item.group_sent.count > 1 {   // sent to a group, color is based on the number of acks
                    print ("sent message to \(item.group_sent.count), acked \(item.group_acked.count)")
                    let factor = CGFloat(item.group_acked.count) / CGFloat(item.group_sent.count)
                    cell.viewMessage.backgroundColor = // if the counts are the same, same color as E2F9CB
                        UIColor(red: 0.8862745098, green: 0.9764705882,
                                blue: 0.7960784313, alpha: factor)
                } else if item.message_has_been_acked == 0 {
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
            let indexPath = IndexPath(item: index, section: 0)
            self.tableView.reloadData()
            self.tableView.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.bottom, animated: true)
        }
    }
    
    func messagesUpdated() {
        if tableView != nil {
            DispatchQueue.main.async {
                self.tableView.reloadData()
                if self.messageVM.count > 0 {
                    let indexPath = IndexPath(row: self.messageVM.count-1, section: 0)
                    self.tableView.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.bottom, animated: true)
                }
            }
        }
    }
}

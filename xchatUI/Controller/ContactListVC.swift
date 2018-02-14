//
//  ContactListVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class ContactListVC: UIViewController {
    
    var message: UITextView?
    var sendButton: UIButton?
    var contactName: UILabel?
    var nMessageLabel: UILabel?
    
    var conversation: ConversationUITextView?
    var cvc: ConversationViewController!
    var mayCreateNewContact: NewContactViewController!
    var more: MoreUIViewController!
    
    var xchat: XChat!
    var contacts: [Any]!
    var hiddenContacts: [Any]!
    var contactsWithNewMessages: [String: Any]!
    var conversationIsDisplayed: Bool!
    var displaySettings: Bool!
    var initialLatestContact: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("in ContactsUITableViewController, view did load")
        self.conversation = nil
        self.xchat = XChat()
        self.contacts = [Any]()
        self.hiddenContacts = [Any]()
        self.contactsWithNewMessages = [String: Any]()
        //setContacts()

        self.mayCreateNewContact = tabBarController!.viewControllers![2] as! NewContactViewController
        //getLatestContact
        
        self.conversationIsDisplayed = false
        self.displaySettings = false
        self.message = nil
        self.sendButton = nil

        self.cvc = tabBarController!.viewControllers![1] as! ConversationViewController
        //register for notifications in cvc
        
        let subViews = self.cvc.view.subviews
        for item in subViews {
            if item is UITextView {
                self.message = item as? UITextView
            }else if item is UIButton {
                self.sendButton = item as? UIButton
            }
        }
        if (self.message != nil) {
            for item in subViews{
                if item is ConversationUITextView {
                    self.conversation = item as? ConversationUITextView
                }else if item is UILabel {
                    if let label =  item as? UILabel {
                        if label.tag == 1  {
                            self.contactName = label
                        } else if label.tag == 2 {
                            self.nMessageLabel = label
                        }
                    }
                }else if item is MoreUIViewController {
                    self.more = item as? MoreUIViewController
                }
            }
        }
        if (self.conversation != nil) {
            //TODO change contactscontroller
            self.xchat.initialize(conversation, contacts: ContactsUITableViewController(), vc: mayCreateNewContact, mvc: more)
            self.conversation?.initialize(xchat.getSocket(), messageField: message, send: sendButton, contact: initialLatestContact, decorativeLabel: nMessageLabel)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.setXChatValue(xchat)
            appDelegate.setConversationValue(conversation)
            //appDelegate.setTvc(self)
        } else {
            NSLog("warning: failed to initialize xchat %@, exiting\n", self.xchat)
            exit (1);
        }
        if (initialLatestContact != nil) {
            if (self.contactName == nil){
                self.contactName = UILabel()
                self.contactName?.text = initialLatestContact
                conversation?.displayContact(initialLatestContact!)
            }
        } else {
            self.contactName?.text = "no contact yet"
            conversation?.displayContact(contactName!.text)
        }
    }
}

extension ContactListVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "", for: indexPath)
        return cell
    }
}

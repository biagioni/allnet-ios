//
//  ContactListVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

@objc class ContactListVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelCountContacts: UILabel!
    
    var contactVM: ContactViewModel!
    
    var message: UITextView?
    var sendButton: UIButton?
    var contactName: UILabel?
    var nMessageLabel: UILabel?
    
    var conversation: ConversationUITextView?
    var cvc: ConversationViewController!
    var mayCreateNewContact: NewContactViewController!
    var more: MoreUIViewController!
    var cHelper: TableViewContactCHelper!
    
    var xchat: XChat!
    var hiddenContacts: [String]?
    var contactsWithNewMessages: NSMutableDictionary! {
        didSet{
            labelCountContacts.text = contactsWithNewMessages.count.description
        }
    }
    var conversationIsDisplayed: Bool!
    var displaySettings: Bool!
    var initialLatestContact: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cHelper = TableViewContactCHelper()
        NSLog("in ContactsUITableViewController, view did load")
        self.conversation = nil
        self.xchat = XChat()
        self.hiddenContacts = [String]()
        self.contactsWithNewMessages = NSMutableDictionary()
        
        contactVM =  ContactViewModel()
        self.navigationItem.title = "\(contactVM.count) Contacts"

        self.mayCreateNewContact = tabBarController!.viewControllers![2] as! NewContactViewController
        
        initialLatestContact = contactVM.latestContact()
        
        self.conversationIsDisplayed = false
        self.displaySettings = false
        self.message = nil
        self.sendButton = nil

        self.cvc = tabBarController!.viewControllers![1] as! ConversationViewController
        cvc.notifyChange(self)
        
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
            //initializa conversation
            self.xchat.initialize(conversation, contacts: self, vc: mayCreateNewContact, mvc: more)
            self.conversation?.initialize(xchat.getSocket(), messageField: message, send: sendButton, contact: initialLatestContact as! String, decorativeLabel: nMessageLabel)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.setXChatValue(xchat)
            appDelegate.setConversationValue(conversation)
            appDelegate.setContactsUITVC(self)
        } else {
            NSLog("warning: failed to initialize xchat %@, exiting\n", self.xchat)
            exit (1);
        }
        if (initialLatestContact != nil) {
            if (self.contactName == nil){
                self.contactName = UILabel()
                self.contactName?.text = initialLatestContact as! String
                conversation?.displayContact(initialLatestContact! as String!)
            }
        } else {
            self.contactName?.text = "no contact yet"
            conversation?.displayContact(contactName!.text)
        }
    }
    
    override func unwind(for unwindSegue: UIStoryboardSegue, towardsViewController subsequentVC: UIViewController) {
    }
    
    func loadData(){
        contactVM.fetchData()
        self.navigationItem.title = "\(contactVM.count) Contacts"
    }
    
    func reIniSocket() {
        conversation?.setSocket(xchat.getSocket())
    }
        
    func newMessage(contact: String){
        cHelper.newMessage(contact, message, conversationIsDisplayed, contactsWithNewMessages, self, tableView)
    }
    
    func notifyConversationChange(beingDisplayed: Bool){
        cHelper.notifyConversationChange(beingDisplayed, conversationIsDisplayed, conversation, self, tableView, contactsWithNewMessages)
    }
}

extension ContactListVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactVM.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell
        if let item = contactVM[indexPath.row] {
            cell.update(with: item)
        }
        return cell
    }
}


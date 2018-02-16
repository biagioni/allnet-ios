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
    var sectionsCount = 1
    
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
        self.displaySettings = false
        
        self.conversationIsDisplayed = false
        
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
    
    @IBAction func showHidden(_ sender: UIBarButtonItem) {
        displaySettings = !displaySettings
        if displaySettings {
            sectionsCount = 2
        }else{
            sectionsCount = 1
        }
        tableView.reloadData()
    }
    
    
    func loadData(){
        contactVM.fetchData()
        self.navigationItem.title = "\(contactVM.count) Contact(s)"
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
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionsCount
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return contactVM.count
        }else{
            return contactVM.hiddenCount
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell
        if indexPath.section == 0 {
            if let item = contactVM[indexPath.row] {
                cell.update(with: item)
            }
        }else{
            if let item = contactVM.hidden(index: indexPath.row) {
                cell.update(with: item)
            }
        }
        return cell
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Visible Contacts"
        }else{
            return "Hidden Contacts"
        }
    }
}

extension ContactListVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if displaySettings {
            
        }else{
            self.performSegue(withIdentifier: "showMessage", sender: nil)
        }
    }
}


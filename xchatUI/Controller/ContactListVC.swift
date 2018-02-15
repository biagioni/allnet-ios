//
//  ContactListVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

//import UIKit
//
//@objc class ContactListVC: UIViewController {
//    
//    var message: UITextView?
//    var sendButton: UIButton?
//    var contactName: UILabel?
//    var nMessageLabel: UILabel?
//    
//    var conversation: ConversationUITextView?
//    var cvc: ConversationViewController!
//    var mayCreateNewContact: NewContactViewController!
//    var more: MoreUIViewController!
//    
//    var xchat: XChat!
//    var contacts: [Any]!
//    var hiddenContacts: [Any]!
//    var contactsWithNewMessages: [String: Any]!
//    var conversationIsDisplayed: Bool!
//    var displaySettings: Bool!
//    var initialLatestContact: String?
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        NSLog("in ContactsUITableViewController, view did load")
//        self.conversation = nil
//        self.xchat = XChat()
//        self.contacts = [Any]()
//        self.hiddenContacts = [Any]()
//        self.contactsWithNewMessages = [String: Any]()
//        setContacts()
//
//        self.mayCreateNewContact = tabBarController!.viewControllers![2] as! NewContactViewController
//        
//        initialLatestContact = latestContact()
//        
//        self.conversationIsDisplayed = false
//        self.displaySettings = false
//        self.message = nil
//        self.sendButton = nil
//
//        self.cvc = tabBarController!.viewControllers![1] as! ConversationViewController
//        //register for notifications in cvc
//        
//        let subViews = self.cvc.view.subviews
//        for item in subViews {
//            if item is UITextView {
//                self.message = item as? UITextView
//            }else if item is UIButton {
//                self.sendButton = item as? UIButton
//            }
//        }
//        if (self.message != nil) {
//            for item in subViews{
//                if item is ConversationUITextView {
//                    self.conversation = item as? ConversationUITextView
//                }else if item is UILabel {
//                    if let label =  item as? UILabel {
//                        if label.tag == 1  {
//                            self.contactName = label
//                        } else if label.tag == 2 {
//                            self.nMessageLabel = label
//                        }
//                    }
//                }else if item is MoreUIViewController {
//                    self.more = item as? MoreUIViewController
//                }
//            }
//        }
//        if (self.conversation != nil) {
//            //self.xchat.initialize(conversation, contacts: self, vc: mayCreateNewContact, mvc: more)
//            self.conversation?.initialize(xchat.getSocket(), messageField: message, send: sendButton, contact: initialLatestContact, decorativeLabel: nMessageLabel)
//            let appDelegate = UIApplication.shared.delegate as! AppDelegate
//            appDelegate.setXChatValue(xchat)
//            appDelegate.setConversationValue(conversation)
//            //appDelegate.setTvc(self)
//        } else {
//            NSLog("warning: failed to initialize xchat %@, exiting\n", self.xchat)
//            exit (1);
//        }
//        if (initialLatestContact != nil) {
//            if (self.contactName == nil){
//                self.contactName = UILabel()
//                self.contactName?.text = initialLatestContact
//                conversation?.displayContact(initialLatestContact!)
//            }
//        } else {
//            self.contactName?.text = "no contact yet"
//            conversation?.displayContact(contactName!.text)
//        }
//    }
//    
//    func reIniSocket() {
//        conversation?.setSocket(xchat.getSocket())
//    }
//    
//    func setContacts(){
//        loadInitialData()
//    }
//    
//    func contactHeaderString(count: Int, newMessages: Bool) -> NSString {
//        var contactsString = "contacts"
//        if count == 1 {
//            contactsString = "contacts"
//        }
//        if newMessages {
//            return NSString(format: "%ld %@ with new messages", count, contactsString)
//        }else{
//            return NSString(format: "%ld %@ total", count, contactsString)
//        }
//    }
//    
//    func contactsHeader(contactsCount: Int, contactsWithMessages: Int) -> [Any] {
//        var result = [Any]()
//        result.append("")
//        let plural = contactsWithMessages != 1
//        var contactsString = "contacts"
//        if !plural {
//            contactsString = "contacts"
//        }
//        let contactsWith = NSString(format: "%ld %@ with new messages", contactsWithMessages, contactsString)
//        result.append(contactsWith)
//        let contactsTotal = NSString(format: "%ld contacts total", contactsCount)
//        result.append(contactsTotal)
//        result.append("")
//        return result
//    }
//    
//    func loadInitialData(){
//        contacts.removeAll()
//        var c:UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
//        var nc = all_contacts(&c)
//        for i  in 0..<nc {
//            let title = NSString(utf8String: c![Int(i)]!)
//            self.contacts.append(title!)
//        }
//        ///TODO sort contacts
//        if c != nil {
//            free(c)
//        }
//        self.contacts = nil
//        
//        hiddenContacts.removeAll()
//        nc = invisible_contacts(&c)
//        for i  in 0..<nc {
//            let title = NSString(utf8String: c![Int(i)]!)
//            self.hiddenContacts.append(title!)
//        }
//        ///TODO sort hiddencontacts
//        if c != nil {
//            free(c)
//        }
//        self.contacts = nil
//    }
//    
//    func lastTime(objCContact: String, msgType: Int) -> Double {
//        var k: UnsafeMutablePointer<keyset>?
//        let contactPointer = objCContact.utf8CString as! UnsafeMutablePointer<CChar>
//        let nk = all_keys(contactPointer, &k)
//        var latest_time: UInt64 = 0
//        for ik in 0..<nk {
//            var seq: UInt64 = 0
//            var time: UInt64 = 0
//            var tz_min: Int32 = 0
//            var ack: UnsafeMutablePointer<CChar>!
//            var mtype = highest_seq_record(contactPointer, k! [Int(ik)], Int32(msgType), &seq, &time, &tz_min, nil, ack, nil, nil);
//            if mtype != MSG_TYPE_DONE && time > latest_time {
//                latest_time = time
//            }
//        }
//        if nk > 0 {
//            free(k)
//        }
//        return Double(latest_time)
//    }
//    
//    func lastReceived(contact: String) -> String? {
//        let latest_time_received = lastTime(objCContact: contact, msgType: Int(MSG_TYPE_RCVD))
//        if latest_time_received == 0 {
//            return nil
//        }
//        let unixTime = latest_time_received + Double(ALLNET_Y2K_SECONDS_IN_UNIX)
//        let date = Date(timeIntervalSince1970: unixTime)
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateStyle = .medium
//        dateFormatter.timeStyle = .medium
//        return dateFormatter.string(from: date)
//    }
//    
//    func latestContact() -> String? {
//        var result: String? = nil
//        var latest: Double = 0
//        if (self.contacts != nil) {
//            for item in self.contacts {
//                if item is String {
//                    let contact = item as! String
//                    let latestForThisContact = lastTime(objCContact: contact, msgType: Int(MSG_TYPE_ANY))
//                    if ((result == nil) || (latest < latestForThisContact)) {
//                        result = contact
//                        latest = latestForThisContact
//                    }
//                }
//            }
//        }
//        return result
//    }
//}
//
//extension ContactListVC: UITableViewDataSource {
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 0
//    }
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "", for: indexPath)
//        return cell
//    }
//}


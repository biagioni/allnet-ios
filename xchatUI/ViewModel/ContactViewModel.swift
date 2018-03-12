//
//  ContactsViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

protocol ContactDelegate {
    func contactUpdated()
    func newMessageReceived(fromContact contact: String)
}

class ContactViewModel: NSObject {
    var delegate: ContactDelegate?
    private var _contacts: [(String, String)]
    private var _groups: [(String, Bool)]
    private var _contact: String?
    private var _cHelper: CHelper!
    private var _hiddenContacts: [(String, String)]{
        didSet{
            delegate?.contactUpdated()
        }
    }
    
    override init() {
        _contacts = [(String, String)]()
        _hiddenContacts = [(String, String)]()
        _groups = [(String, Bool)]()
    }
    
    subscript(index: Int) -> (String, String)? {
        return _contacts.count > 0 ? _contacts[index] : nil
    }
    
    func hidden(index: Int) -> (String, String)? {
        return _hiddenContacts.count > 0 ? _hiddenContacts[index] : nil
    }
    
    func groups(index: Int) -> (String, Bool)? {
        return _groups.count > 0 ? _groups[index] : nil
    }
    
    func loadMembers(){
        _groups.removeAll()
        fetchData()
        var allMembers = [String]()
        var pointer: PointerMz
        let n = group_membership(_contact, &pointer)
        for i in 0..<n {
            allMembers.append(String(cString: pointer![Int(i)]!))
        }
        _groups = _contacts.map{($0.0, allMembers.contains($0.0))}.filter{$0.0 != _contact!}
    }
    func loadGroups(){
        _groups.removeAll()
        fetchData()
        var allGroups = [String]()
        var pointer: PointerMz
        let n = member_of_groups(_contact, &pointer)
        for i in 0..<n {
            allGroups.append(String(cString: pointer![Int(i)]!))
        }
        let groups = _contacts.filter{isGroup($0.0)}
        _groups = groups.map{($0.0, allGroups.contains($0.0))}
    }
    
    var groupsCount: Int {
        return _groups.count
    }
    
    var hiddenCount: Int {
        return _hiddenContacts.count
    }
    
    var messageSize: String {
        return _cHelper.getMessagesSize()
    }
    
    var selectedContact: String? {
        return _contact
    }
    
    var count: Int {
        return _contacts.count
    }
    
    func isGroup(_ contact: String?) -> Bool {
        if contact != nil {
            return  is_group(contact!) == 1
        }else{
           return  is_group(_contact) == 1
        }
    }
    
    func setContact(contact: String, sock: Int32) {
        _cHelper = CHelper()
        _contact = contact
        _cHelper.initialize(sock, _contact)
    }
    
    func indexOf(contact: String) -> Int? {
        return _contacts.index(where: {$0.0 == contact})
    }
    
    func setTimeForNewMessage(index: Int){
        _contacts[index].1 = lastReceived(contact: _contacts[index].0)
    }
    
    func fetchData(){
        _contacts.removeAll()
        _hiddenContacts.removeAll()
        var c:PointerMz
        var nc = all_contacts(&c)
        for i  in 0..<nc {
            if let title = String(utf8String: c![Int(i)]!) {
                _contacts.append(title, lastReceived(contact: title))
            }
        }
        _contacts.sort(by: {lastTime(objCContact: $0.0, msgType: Int(MSG_TYPE_RCVD)) < lastTime(objCContact: $1.0, msgType: Int(MSG_TYPE_RCVD))})
        if c != nil {
            free(c)
        }
        nc = invisible_contacts(&c)
        for i  in 0..<nc {
            if let title = String(utf8String: c![Int(i)]!) {
                _hiddenContacts.append(title, lastReceived(contact: title))
            }
        }
        _hiddenContacts.sort(by: {lastTime(objCContact: $0.0, msgType: Int(MSG_TYPE_RCVD)) < lastTime(objCContact: $1.0, msgType: Int(MSG_TYPE_RCVD))})
        if c != nil {
            free(c)
        }
    }
    
    func latestContact() -> String? {
        var result: String? = nil
        var latest: Double = 0
        for item in _contacts {
            let contact = item.0
            let latestForThisContact = lastTime(objCContact: contact, msgType: Int(MSG_TYPE_ANY))
            if ((result == nil) || (latest < latestForThisContact)) {
                result = contact
                latest = latestForThisContact
            }
        }
        return result
    }
    
    func lastTime(objCContact: String, msgType: Int) -> Double {
        var k: Keyset
        let contactPointer = (objCContact as NSString).utf8String//objCContact.utf8CString
        let nk = all_keys(contactPointer, &k)
        var latest_time: UInt64 = 0
        for ik in 0..<nk {
            var seq: UInt64 = 0
            var time: UInt64 = 0
            var tz_min: Int32 = 0
            var ack: Int8 = 0
            let mtype = highest_seq_record(contactPointer, k! [Int(ik)], Int32(msgType), &seq, &time, &tz_min, nil, &ack, nil, nil);
            if mtype != MSG_TYPE_DONE && time > latest_time {
                latest_time = time
            }
        }
        if nk > 0 {
            free(k)
        }
        return Double(latest_time)
    }
    
    func lastReceived(contact: String) -> String {
        let latest_time_received = lastTime(objCContact: contact, msgType: Int(MSG_TYPE_RCVD))
        if latest_time_received == 0 {
            return "No message"
        }
        let unixTime = latest_time_received + Double(ALLNET_Y2K_SECONDS_IN_UNIX)
        let date = Date(timeIntervalSince1970: unixTime)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: date)
    }
}

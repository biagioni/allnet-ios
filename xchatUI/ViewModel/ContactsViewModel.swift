//
//  ContactsViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class ContactViewModel {
    private var _contacts: [(String, String)]
    private var _hiddenContacts: [(String, String)]
    
    init() {
        _contacts = [(String, String)]()
        _hiddenContacts = [(String, String)]()
        fetchData()
    }
    
    subscript(index: Int) -> (String, String)? {
        return _contacts.count > 0 ? _contacts[0] : nil
    }
    
    func hidden(index: Int) -> (String, String)? {
        return _hiddenContacts.count > 0 ? _hiddenContacts[0] : nil
    }
    
    var hiddenCount: Int {
        return _hiddenContacts.count
    }
    
    
    var count: Int {
        return _contacts.count
    }
    
    func fetchData(){
        _contacts.removeAll()
        _hiddenContacts.removeAll()
        var c:UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        var nc = all_contacts(&c)
        for i  in 0..<nc {
            if let title = String(utf8String: c![Int(i)]!) {
                _contacts.append(title, lastReceived(contact: title))
            }
        }
        ///TODO sort contacts
        if c != nil {
            free(c)
        }
        nc = invisible_contacts(&c)
        for i  in 0..<nc {
            if let title = String(utf8String: c![Int(i)]!) {
                _hiddenContacts.append(title, lastReceived(contact: title))
            }
        }
        ///TODO sort hiddencontacts
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
        var k: UnsafeMutablePointer<keyset>?
        let contactPointer = (objCContact as NSString).utf8String//objCContact.utf8CString
        let nk = all_keys(contactPointer, &k)
        var latest_time: UInt64 = 0
        for ik in 0..<nk {
            var seq: UInt64 = 0
            var time: UInt64 = 0
            var tz_min: Int32 = 0
            var ack: UnsafeMutablePointer<CChar>!
            let mtype = highest_seq_record(contactPointer, k! [Int(ik)], Int32(msgType), &seq, &time, &tz_min, nil, ack, nil, nil);
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

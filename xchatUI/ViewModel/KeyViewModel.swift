//
//  KeyViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/25/18.
//  Copyright © 2018 allnet. All rights reserved.
//

protocol KeyExchangeDelegate {
    func notificationOfGeneratedKey(forContact contact: String)
    func notificationkeyExchangeCompleted(forContact contact: String)
}

class KeyViewModel: NSObject {
    var delegate: KeyExchangeDelegate?
    private var _pointer: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?
    var incompleteKeysExchanges: [String]
    
    override init() {
        incompleteKeysExchanges = [String]()
    }
    
    func fetchIncompletedKeys(){
        incompleteKeysExchanges.removeAll()
        let keyArray = incomplete_key_exchanges(&_pointer, nil, nil)
        for i in 0..<keyArray {
            incompleteKeysExchanges.append(String(NSString(utf8String: _pointer![Int(i)]!)!))
        }
    }
    
    func notificationOfGeneratedKey(forContact contact: String){
        delegate?.notificationOfGeneratedKey(forContact: contact)
    }
    
    func notificationkeyExchangeCompleted(forContact contact: String){
        delegate?.notificationkeyExchangeCompleted(forContact: contact)
    }
    
    func getKeyFor(contact: String) -> String? {
        return CHelper.getKeyFor(contact)
    }
}

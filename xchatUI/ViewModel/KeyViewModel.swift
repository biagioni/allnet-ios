//
//  KeyViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/25/18.
//  Copyright © 2018 allnet. All rights reserved.
//


class KeyViewModel {
    private var _contact: String
    private var _pointer: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?
    var incompleteKeysExchanges: [String]
    
    init(contact: String) {
        _contact = contact
        incompleteKeysExchanges = [String]()
    }
    
    func fetchIncompletedKeys(){
        incompleteKeysExchanges.removeAll()
        let keyArray = incomplete_key_exchanges(&_pointer, nil, nil)
        for i in 0..<keyArray {
            incompleteKeysExchanges.append(String(NSString(utf8String: _pointer![Int(i)]!)!))
        }
    }
    
    func getKeyFor(contact: String) -> String{
        return CHelper.getKeyFor(contact)
    }
}

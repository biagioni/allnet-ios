//
//  MessageViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

class MessageViewModel {
    private var _contact: String
    var cHelper: CHelper!
    private var _messages: [MessageModel]
    
    init(contact: String, sock: Int32) {
        cHelper = CHelper()
        _contact = contact
        cHelper.initialize(sock, _contact)
        _messages = [MessageModel]()
        _messages = cHelper.getMessages() as! [MessageModel]
    }
    
    subscript(index: Int) -> MessageModel? {
        return _messages.count > 0 ? _messages[index] : nil
    }
    
    var count: Int {
        return _messages.count
    }
}

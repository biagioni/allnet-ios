//
//  MessageViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

protocol MessageDelegate {
    func messagesUpdated()
    func newMessageReceived(fromContact contact: String)
}


class MessageViewModel : NSObject {
    var delegate: MessageDelegate?
    private var _contact: String
    private var _cHelper: CHelper!
    private var _messages: [MessageModel]{
        didSet{
            delegate?.messagesUpdated()
        }
    }
    
    init(contact: String, sock: Int32) {
        _cHelper = CHelper()
        _contact = contact
        _cHelper.initialize(sock, _contact)
        _messages = [MessageModel]()
    }
    
    func receivedNewMessage(forContact contact: String){
        if contact == contact {
            fetchData()
        }else{
            delegate?.newMessageReceived(fromContact: contact)
        }
    }
    
    func fetchData(){
        _messages = _cHelper.getMessages() as! [MessageModel]
    }
    
    subscript(index: Int) -> MessageModel? {
        return _messages.count > 0 ? _messages[index] : nil
    }
    
    var count: Int {
        return _messages.count
    }
}

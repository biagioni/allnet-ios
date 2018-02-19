//
//  MessageViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

protocol MessageDelegate {
    func messagesUpdated()
}


class MessageViewModel : NSObject {
    var delegate: MessageDelegate?
    var contactDelegate: ContactDelegate?
    private var _contact: String?
    private var _cHelper: CHelper!
    private var _messages: [MessageModel]{
        didSet{
            delegate?.messagesUpdated()
        }
    }
    
    override init() {
        _messages = [MessageModel]()
    }
    
    func setContact(contact: String, sock: Int32) {
        _messages.removeAll()
        _cHelper = CHelper()
        _contact = contact
        _cHelper.initialize(sock, _contact)
    }
    
    func removeContact(){
        _contact = nil
    }
    func receivedNewMessage(forContact contact: String){
        if contact == _contact {
            fetchData()
        }else{
            contactDelegate?.newMessageReceived(fromContact: contact)
        }
    }
    
    func sendMessage(message: String){
        _cHelper.sendMessage(message)
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

//
//  MessageViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

let MSG_MISSED = 1212

protocol MessageDelegate {
    func messagesUpdated()
    func addedNewMessage(index: Int)
    func ackMessages(forIndexes indexes: [Int])
}


class MessageViewModel : NSObject {
    var delegate: MessageDelegate?
    var contactDelegate: ContactDelegate?
    private var _contact: String?
    private var _cHelper: CHelper!
    private var _messages: [MessageModel]
    
    override init() {
        _messages = [MessageModel]()
    }
    
    subscript(index: Int) -> MessageModel? {
        return _messages.count > 0 ? _messages[index] : nil
    }
    
    var count: Int {
        return _messages.count
    }
    
    var selectedContact: String? {
        return _contact
    }
    
    func setContact(contact: String, sock: Int32) {
        _messages.removeAll()
        delegate?.messagesUpdated()
        _cHelper = CHelper()
        _contact = contact
        _cHelper.initialize(sock, _contact)
    }
    
    func removeContact(){
        _contact = nil
    }
    
    func lastTimeRead() -> UInt64 {
        return _cHelper.last_time_read(_contact)
    }
    
    func receivedNewMessage(forContact contact: String, message: String){
        if contact == _contact {
            let messages = _cHelper.getMessages() as! [MessageModel]
            _messages = messages
            checkMissingMessages()
            delegate?.addedNewMessage(index: count-1)
        }else{
            contactDelegate?.newMessageReceived(fromContact: contact, message: message)
        }
    }
    
    func ackMessage(forContact contact: String){
        if contact == _contact {
            let messages = _cHelper.getMessages() as! [MessageModel]
            var modifiedMessagesIndexes = messages.enumerated().map{$0.element.message_has_been_acked == _messages[$0.offset].message_has_been_acked ? nil :  $0.offset}
            _messages = messages
            checkMissingMessages()
            modifiedMessagesIndexes = modifiedMessagesIndexes.filter{$0 != nil}
            delegate?.ackMessages(forIndexes: modifiedMessagesIndexes as! [Int])
        }
    }
    
    func sendMessage(message: String){
        _messages.append(_cHelper.sendMessage(message))
        delegate?.addedNewMessage(index: count-1)
    }
    
    func fetchData(){
        _messages = _cHelper.getMessages() as! [MessageModel]
        checkMissingMessages()
        delegate?.messagesUpdated()
    }
    
    func checkMissingMessages(){
        let missingMessages = _messages.enumerated().filter{ index, element in element.prev_missing > 0}
        for msg in missingMessages {
            let msgModel = MessageModel()
            msgModel.message_has_been_acked = msg.element.message_has_been_acked
            msgModel.message = "\(msg.element.prev_missing) message\(msg.element.prev_missing == 1 ? "" : "s") missing"
            msgModel.msg_type = Int32(MSG_MISSED)
            _messages.insert(msgModel, at: msg.offset + 1)
        }
    }
}

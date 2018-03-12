//
//  NetworkManager.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 3/11/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import Foundation

class NetworkManager {
    private var _sock: Int
    private var _contact: String
    
    init(sock: Int, contact: String) {
        _sock = sock
        _contact = contact
        updateTimeRead(contact: contact)
    }
    
    func updateTimeRead(contact: String){
        var k: Keyset
        let nkeys = all_keys(contact, &k)
        for ikey in 0..<nkeys{
            if let path = contactLastReadPath(contact: contact, k: k![Int(ikey)]){
                NSLog("update_time_read path is %s\n", path)
                let fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR)
                write(fd, " ", 1)
                close (fd)  /* all we are doing is setting the modification time */
            }
        }
        free(k)
    }
    
    func contactLastReadPath(contact: String, k: keyset) -> String? {
        let directory = key_dir (k)
        if directory != nil {
            var dir = String(cString: directory!)
            dir = dir.replacingOccurrences(of: "contacts", with: "xchat")
            let path = strcat3_malloc(dir, "/", "last_read", "contact_last_read_path");
            free (directory);
            return String(cString: path!)
        }
        return nil
    }
    
    func getMessagesSize(contact: String) -> String {
        let sizeInBytes = conversation_size (contact)
        let sizeInMegabytes = sizeInBytes / (1000 * 1000);
        var buffer: Int8 = 0
        if sizeInMegabytes >= 10 {
            _ = snprintf(ptr: &buffer, MemoryLayout<Int8>.size, "% \(PRId32)", sizeInMegabytes)
        } else {
            _ = snprintf(ptr: &buffer, MemoryLayout<Int8>.size, "% \(PRId32) .%02 \(PRId32) ", sizeInMegabytes, (sizeInBytes / 10000) % 100)
        }
        return String(utf8String: &buffer)!
    }
    
    func  generateRandoKey() -> String {
        var buffer: Int8 = 0
        random_string(&buffer, 15)
        normalize_secret(&buffer)
        return String(utf8String: &buffer)!
    }
    
    func getMessages(contact: String) -> [MsgModel] {
        updateTimeRead(contact: contact)
        var k: Keyset
        let nk = all_keys(contact, &k)
        var result_messages = [MsgModel]()
        for ik in 0..<nk{
            if let iter = start_iter(contact, k![Int(ik)]){
                var seq: UInt64 = 0
                var time: UInt64 = 0
                var rcvd_time: UInt64 = 0
                var tz_min:Int32 = 0
                var ack: Int8 = 0
                var msize: Int32 = 0
                var message: UnsafeMutablePointer<Int8>? = nil
                var next = prev_message(iter, &seq, &time, &tz_min, &rcvd_time, &ack, &message, &msize)
                while (next != MSG_TYPE_DONE) {
                    if ((next == MSG_TYPE_RCVD) || (next == MSG_TYPE_SENT)) {  // ignore acks
                        
//                        if message != nil {
//                            var mi = MsgModel(message: String(cString: message!), msg_type: Int(next), dated: basicDate(mi.time, mi.tz_min), message_has_been_acked: 0, msize: Int(msize), seq: seq, prev_missing: 0)
//                            if (next == MSG_TYPE_SENT) && (is_acked_one(contact, k![Int(ik)], seq, nil)) == 1 {
//                                mi.message_has_been_acked = 1
//                            }
//                            result_messages.append(mi)
//                        }
                    }
                    free(message)
                    message = nil
                    next =  prev_message(iter, &seq, &time, &tz_min, &rcvd_time, &ack, &message, &msize)
                }
                free_iter(iter)
            }
        }
        if (nk > 0){  // release the storage for the keys
            free(k)
        }
        result_messages = result_messages.sorted(by: {$0.dated < $1.dated})
        return result_messages
    }

}

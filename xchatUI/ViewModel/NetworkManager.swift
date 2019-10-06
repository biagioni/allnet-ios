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
        var k: Keyset = nil
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
    
    func  generateRandomKey() -> String {
        var buffer: Int8 = 0
        random_string(&buffer, 15)
        normalize_secret(&buffer)
        return String(utf8String: &buffer)!
    }
    
    func getMessages(contact: String) -> [MsgModel] {
        updateTimeRead(contact: contact)
        var k: Keyset = nil
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
                var message: Pointer? = nil
                var next = prev_message(iter, &seq, &time, &tz_min, &rcvd_time, &ack, &message, &msize)
                while (next != MSG_TYPE_DONE) {
                    if ((next == MSG_TYPE_RCVD) || (next == MSG_TYPE_SENT)) {  // ignore acks
                        if message != nil {
                            var model = MsgModel(message: String(cString: message!), msg_type: Int(next), dated: basicDate(time: Int(time), tzMin: Int(tz_min)), received: basicDate(time: Int(rcvd_time), tzMin: localTimeOffset()), message_has_been_acked: 0, msize: Int(msize), seq: Int(seq), prev_missing: 0)
                            print("received at ", model.received)
                            if (next == MSG_TYPE_SENT) && (is_acked_one(contact, k![Int(ik)], seq, nil)) == 1 {
                                model.message_has_been_acked = 1
                            }
                            result_messages.append(model)
                        }
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
    
    func basicDate(time: Int, tzMin: Int) -> String {
        let unixTime: TimeInterval = Double(time) + Double(ALLNET_Y2K_SECONDS_IN_UNIX)
        let date = Date(timeIntervalSince1970: unixTime)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        var dateString = dateFormatter.string(from: date)
        if localTimeOffset() != tzMin {
            // some of this code from cutil.c
            var delta = tzMin - localTimeOffset()
            while (delta < 0){
                delta += 0x10000 // 16-bit value
            }
            if (delta >= 0x8000){
                delta = 0x10000 - delta
            }
            let offset =  String(format: " (%+d:%d)", delta / 60, delta % 60)
            dateString = dateString.appending(offset)
        }
        dateString = dateString.appending("\n")
        return dateString
    }
    
    func localTimeOffset() -> Int {
        var now = time(nil)
        var now_ltime_tm = tm()
        localtime_r (&now, &now_ltime_tm);
        var gtime_tm = tm()
        gmtime_r (&now, &gtime_tm);
        return (deltaMinutes(local: now_ltime_tm, gm: gtime_tm));
    }
    
    func deltaMinutes(local: tm, gm: tm) -> Int {
        var delta_hour = local.tm_hour - gm.tm_hour
        if local.tm_wday == ((gm.tm_wday + 8) % 7) {
            delta_hour += 24
        } else if (local.tm_wday == ((gm.tm_wday + 6) % 7)) {
            delta_hour -= 24
        } else if (local.tm_wday != gm.tm_wday) {
            NSLog("assertion error: weekday %d != %d +- 1\n", local.tm_wday, gm.tm_wday)
            exit (1)
        }
        var delta_min = local.tm_min - gm.tm_min
        if (delta_min < 0) {
            delta_hour -= 1
            delta_min += 60
        }
        let result = delta_hour * 60 + delta_min
        return Int(result)
    }
    
    func getKeyFor(contact: String) -> String? {
        var randomSecret:String? = nil
        var enteredSecret:String? = nil
        var keys: Keyset = nil
        let nk = all_keys (contact, &keys);
        for ki in 0..<nk {
            var s1: Pointer?
            var s2: Pointer?
            var content: Pointer?
            incomplete_exchange_file(contact, keys![Int(ki)], &content, nil)
            if (content != nil) {
                var first = index(content, Int32("\n")!)
                if (first != nil) {
                    first = Pointer(mutating: (("\0") as NSString).utf8String)  // null terminate hops count
                    s1 = first! + 1
                    var second = index (s1, Int32("\n")!)
                    if (second != nil) {
                        second = Pointer(mutating: (("\0") as NSString).utf8String)   // null terminate first secret
                        s2 = second! + 1
                        var third = index (s2, Int32("\n")!)
                        if (third != nil){
                            third = Pointer(mutating: (("\0") as NSString).utf8String)
                        }
                        if (s2 == Pointer(mutating: (("\0") as NSString).utf8String) ){
                            s2 = nil
                        }
                    }
                    if (s1 != nil){
                        randomSecret = String(cString: s1!)
                    }
                    if (s2 != nil){
                        enteredSecret = String(cString: s2!)
                    }
                    free(content)
                }
            }
            if (keys != nil) {
                free(keys)
            }
        }
        print(enteredSecret ?? "")
        return randomSecret
    }
}

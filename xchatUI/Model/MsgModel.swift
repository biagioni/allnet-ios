//
//  MsgModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 3/12/18.
//  Copyright © 2018 allnet. All rights reserved.
//

struct MsgModel {
    var message: String
    var msg_type: Int
    var dated: String
    var message_has_been_acked: Int
    var msize: Int
    var seq: Int
    var prev_missing: Int
}

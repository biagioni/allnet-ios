//
//  MoreViewModel.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 3/2/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

protocol MoreDelegate {
    func tracing(message: String)
}
class MoreViewModel: NSObject {
    var delegate: MoreDelegate?
    
    func receiveTrace(message: String){
        delegate?.tracing(message: message)
    }
}

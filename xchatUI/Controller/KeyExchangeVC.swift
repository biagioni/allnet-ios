//
//  KeyExchangeVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/25/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class KeyExchangeVC: UIViewController {
    
    @IBOutlet weak var labelGeneratedKey: UILabel!
    @IBOutlet weak var labelInformedKey: UILabel!
    @IBOutlet weak var textViewInformation: UITextView!
    
    var info: (name: String, key: String?, hops: Int)!
    var isGroup: Bool!
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        if isGroup {
            appDelegate.xChat.requestKey(info.name, maxHops: 10)
        }else{
            var randomString: UnsafeMutablePointer<CChar>!
            random_string(randomString, 15)
            normalize_secret(randomString)
            appDelegate.xChat.requestNewContact(info.name, maxHops: UInt(info.hops), secret1: NSString(utf8String: randomString)! as String, optionalSecret2: info.key)
        }
    }
}

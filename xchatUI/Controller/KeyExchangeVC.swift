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
        var randomString = CHelper.generateRandoKey()
        
        if isGroup {
            appDelegate.xChat.requestKey(info.name, maxHops: UInt(info.hops))
            labelGeneratedKey.text = "None"
            labelInformedKey.text =  "None"
            textViewInformation.textColor = UIColor(hex: "19BB7B")
            textViewInformation.text = "Created group \(info.name) with success!"
        }else{
            if info.hops == 1 {
                randomString = randomString?.substring(to: (randomString?.index((randomString?.startIndex)!, offsetBy: 6))!)
            }
            appDelegate.xChat.requestNewContact(info.name, maxHops: UInt(info.hops), secret1: randomString, optionalSecret2: info.key)
            labelGeneratedKey.text = randomString
            info.key = info.key ?? ""
            labelInformedKey.text = !(info.key?.isEmpty)! ? info.key! : "None"
            textViewInformation.textColor = UIColor(hex: "A85363")
            textViewInformation.text = "Key exchange in progress\nKey was sent\nWaiting for key from:\n\(info.name)"
        }
    }
    
    override func willMove(toParentViewController parent: UIViewController?) {
        super.willMove(toParentViewController: parent)
        if parent == nil {
            appDelegate.xChat.completeExchange(info.name)
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    @IBAction func cancelRequest(_ sender: UIBarButtonItem) {
        ///TODO if request was not completed
        appDelegate.xChat.removeNewContact(info.name)
    }
    
    @IBAction func resendRequest(_ sender: UIButton) {
        appDelegate.xChat.resendKey(forNewContact: info.name)
    }
}

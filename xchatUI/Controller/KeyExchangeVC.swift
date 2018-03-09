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
    var keyVM: KeyViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.view.backgroundColor = UIColor.white
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        keyVM.delegate = self
        appDelegate.xChat.setKeyVM(keyVM)
        
        var randomString = CHelper.generateRandoKey()
        
        if isGroup {
            if create_group(info.name) == 1 {
                labelGeneratedKey.text = "None"
                labelInformedKey.text =  "None"
                textViewInformation.textColor = UIColor(hex: "19BB7B")
                textViewInformation.text = "Created group \(info.name) with success!"
            }else{
                textViewInformation.textColor = UIColor(hex: "A85363")
                textViewInformation.text = "It was not possible to create the group \(info.name)."
            }
        }else{
            if info.hops == 1 {
                randomString = randomString?.substring(to: (randomString?.index((randomString?.startIndex)!, offsetBy: 6))!)
            }
            appDelegate.xChat.requestNewContact(info.name, maxHops: UInt(info.hops), secret1: randomString, optionalSecret2: info.key)
            labelGeneratedKey.text = randomString
            info.key = info.key ?? ""
            labelInformedKey.text = !(info.key?.isEmpty)! ? info.key! : "None"
            textViewInformation.textColor = UIColor(hex: "A85363")
            textViewInformation.text = "Key exchange in progress\nWaiting for key from:\n\(info.name)"
        }
    }
    
    override func willMove(toParentViewController parent: UIViewController?) {
        super.willMove(toParentViewController: parent)
        if parent == nil {
            appDelegate.xChat.completeExchange(info.name)
            self.tabBarController?.selectedIndex = 0
        }
    }
    
    @IBAction func cancelRequest(_ sender: UIBarButtonItem) {
        ///TODO if request was not completed
        appDelegate.xChat.removeNewContact(info.name)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func resendRequest(_ sender: UIButton) {
        appDelegate.xChat.resendKey(forNewContact: info.name)
    }
}

extension KeyExchangeVC: KeyExchangeDelegate {
    func notificationOfGeneratedKey(forContact contact: String) {
        DispatchQueue.main.async {
            self.textViewInformation.textColor = UIColor(hex: "A85363")
            self.textViewInformation.text = "Key was sent\nWaiting for key from:\n\(contact)"
        }
    }
    
    func notificationkeyExchangeCompleted(forContact contact: String) {
        DispatchQueue.main.async {
            self.textViewInformation.textColor = UIColor(hex: "19BB7B")
            self.textViewInformation.text = "Key was exchanged with SUCCESS!!!"
        }
    }
}

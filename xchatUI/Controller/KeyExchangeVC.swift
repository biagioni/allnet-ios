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
    var isExchanged: Bool!
    var contactName = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.view.backgroundColor = UIColor.white
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        keyVM.delegate = self
        appDelegate.xChat.setKeyVM(keyVM)
        
        var randomString = CHelper.generateRandomKey()
        
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
                // randomString = randomString?.substring(to: (randomString?.index((randomString?.startIndex)!, offsetBy: 6))!)
                let offset = (randomString?.index((randomString?.startIndex)!, offsetBy: 6))!
                let newString: String = String(randomString![..<offset])
                // let prtRandom: String = randomString!
                // NSLog("random string %@, newString %@\n", prtRandom, newString);
                randomString = addSpaces (s: newString)
            }
            let s1 = addSpaces (s: ((info.key == nil) || (info.key!.count <= 0)) ? randomString! : info.key)
            print ("info.key is ", info.key!, ", s1 ", s1)
            contactName = info.name
            appDelegate.xChat.requestNewContact(info.name, maxHops: UInt(info.hops), secret1: s1, optionalSecret2: nil)
            labelGeneratedKey.text = s1
            info.key = info.key ?? ""
            // labelInformedKey.text = !(info.key?.isEmpty)! ? info.key! : "None"
            labelInformedKey.text = "None"
            textViewInformation.textColor = UIColor(hex: "A85363")
            textViewInformation.text = "Key exchange in progress\nWaiting for key from:\n\(info.name)"
        }
    }
    
    func addSpaces (s: String?) -> String {
        var result = ""
        var count = 0
        if s != nil {
            for c in s! {
                result.append (c)
                count = count + 1
                if count >= 5 {
                    result = result + " "
                    count = 0
                }
            }
        }
        return result.uppercased()
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.tabBarController?.selectedIndex = 0
        }
    }
    
    @IBAction func cancelRequest(_ sender: UIBarButtonItem) {
        NSLog("Cancel Request")
        ///TODO if request was not completed
        appDelegate.xChat.removeNewContact(info.name)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func doneRequest(_ sender: UIBarButtonItem) {
        NSLog("Done Request")
        ///TODO if request was completed --- should restore the button
        appDelegate.xChat.completeExchange(contactName)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func resendRequest(_ sender: UIButton) {
        appDelegate.xChat.resendKey(forNewContact: info.name)
    }
}

extension KeyExchangeVC: KeyExchangeDelegate {
    func notificationOfGeneratedKey(forContact contact: String) {
        DispatchQueue.main.async {
            if self.isExchanged {
                self.notificationkeyExchangeCompleted(forContact: contact)
            } else {
                self.textViewInformation.textColor = UIColor(hex: "A85363")
                self.textViewInformation.text = "Key was sent\nWaiting for key from:\n\(contact)"
            }
        }
    }
    
    func notificationkeyExchangeCompleted(forContact contact: String) {
        // appDelegate.xChat.completeExchange(contact)
        // rename cancel button to "Done"
        let uib: UIBarButtonItem = UIBarButtonItem (title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(self.doneRequest(_:)))
        self.navigationItem.rightBarButtonItem = uib
        DispatchQueue.main.async {
            self.isExchanged = true
            self.textViewInformation.textColor = UIColor(hex: "19BB7B")
            self.textViewInformation.text = "Received key from " + self.info.name
        }
    }
}

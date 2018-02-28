//
//  MoreVC.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/27/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

class MoreVC: UITableViewController {

    @IBOutlet weak var textFieldHops: UITextField!
    @IBOutlet weak var switchDetails: UISwitch!
    @IBOutlet weak var textViewTraceOutput: UITextView!
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        appDelegate = UIApplication.shared.delegate as! AppDelegate
    }
    
    @IBAction func startTracing(_ sender: UIButton) {
        guard let hops = textFieldHops.text, !hops.isEmpty else {
            ///TODO MESSAGE
            return
        }
        appDelegate.xChat.startTrace(true, maxHops: UInt(Int(hops)!), showDetails: switchDetails.isOn)
        
        ///TODO run in a different thread
        let text = appDelegate.xChat.trace(true, maxHops: UInt(Int(hops)!))
        textViewTraceOutput.text = text
    }
}

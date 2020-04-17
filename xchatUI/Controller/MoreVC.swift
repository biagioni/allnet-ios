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
    var moreVM: MoreViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.view.backgroundColor = UIColor.white
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        moreVM = MoreViewModel()
        moreVM.delegate = self
        appDelegate.xChat.setMoreVM(moreVM)
    }
    
    @IBAction func clearData(_ sender: UIBarButtonItem) {
        textViewTraceOutput.text = ""
    }
    
    @IBAction func startTracing(_ sender: UIButton) {
        guard let hops = textFieldHops.text, !hops.isEmpty else {
            ///TODO MESSAGE
            return
        }
        appDelegate.xChat.startTrace(true, maxHops: UInt(Int(hops)!), showDetails: switchDetails.isOn)
    }
}

extension MoreVC: MoreDelegate {
    func tracing(message: String) {
        let text = textViewTraceOutput.text
        textViewTraceOutput.text = text!  + message
        if textViewTraceOutput.contentSize.height > 200 {
            let bottomOffset = CGPoint(x: 0, y: textViewTraceOutput.contentSize.height - textViewTraceOutput.bounds.size.height)
            textViewTraceOutput.setContentOffset(bottomOffset, animated: true)
        }
    }
}

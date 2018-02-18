//
//  NewDelegate.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/17/18.
//  Copyright © 2018 allnet. All rights reserved.
//
import UIKit

class NewDelegate {
    
    var window: UIWindow?
    var appCHelper: AppDelegateCHelper!
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        appCHelper = AppDelegateCHelper()
        createAllnetDirectory(application: application)
        return true
    }
    
    func createAllnetDirectory(application: UIApplication){
        guard let appSuportDir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            print("unable to create allnet application dir")
            return
        }
        var allnetDir = appSuportDir.appendingPathComponent("allnet", isDirectory: true)
        guard (try? FileManager.default.createDirectory(atPath: allnetDir.path, withIntermediateDirectories: true, attributes: nil)) != nil else {
            print("unable to create allnet dir")
            return
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        guard (try? allnetDir.setResourceValues(resourceValues)) != nil else {
            print("error excluding from backup")
            return
        }
        appCHelper.createAllNetDir(allnetDir)
        appCHelper.start_allnet(application, start_everything: true)
        
        ///TODO NOTIFICATIONS
        
        appCHelper.setPeer()
    }
}

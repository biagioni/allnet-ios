//
//  AppDelegate.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 3/1/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit
import NotificationCenter
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate{
    
    var window: UIWindow?
    var appCHelper: AppDelegateCHelper!
    var authorizationGranted = false
    var xChat: XChat!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        self.xChat = XChat()
        appCHelper = AppDelegateCHelper()
        createAllNetDir()
        appCHelper.start_allnet(application, start_everything: true)
        sleep(1)
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                self.authorizationGranted = granted
            }
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        application.applicationIconBadgeNumber = 0
        
        appCHelper.setPeer()
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: .UIDeviceBatteryStateDidChange, object: nil)
        
        return true
    }
    
    @objc func batteryChanged(){
        set_speculative_computation (UIDevice.current.batteryState != UIDeviceBatteryState.unplugged ? 0 : 1)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        enterBackground()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        enterBackground()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        appCHelper.start_allnet(application, start_everything: false)
        set_speculative_computation (UIDevice.current.batteryState != UIDeviceBatteryState.unplugged ? 0 : 1)
    }
    
    func notifyMessageReceived(contact: String, message: String){
        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            content.title = contact
            content.body = message
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "testRequest", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
                
            })
        }
    }
    
    func enterBackground(){
        appCHelper.acacheSaveData()
        set_speculative_computation(0);
    }
    
    func createAllNetDir() {
        do {
            let applicationSupportDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            var allnetDir = applicationSupportDirectory.appendingPathComponent("allnet", isDirectory: true)
            try FileManager.default.createDirectory(atPath: allnetDir.path, withIntermediateDirectories: true, attributes: nil)
            allnetDir.setTemporaryResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
            let newPath =  allnetDir.path.replacingOccurrences(of: "/Library/Application Support/allnet", with: "")
            //chdir change folder in system
            chdir(newPath)
        }catch(let error){
            print(error)
        }
    }
}

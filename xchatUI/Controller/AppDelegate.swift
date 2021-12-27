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
import MultipeerConnectivity
import AVFoundation   // play a sound

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var authorizationGranted = false
    var xChat: XChat!
    var connected = false
    var firstCall =  true
    var currentPeerID: MCPeerID!
    var sessions: [MCSession]!
    // this socket and address are used to forward packets received from multipeer to ad and back
    var mp_socket: Int32 = -1
    var socket_counter: Int64 = 0    // incremented every time we re-open the socket
    let mp_sin: sockaddr_in = sockaddr_in (
        sin_len: __uint8_t (16),
        sin_family: sa_family_t (AF_INET),
        sin_port: UInt16(allnet_htons (Int32(ALLNET_PORT))),
        sin_addr: in_addr(s_addr: UInt32(allnet_htonl(0x7f000001))),
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    var last_sent: UInt64 = 0
    var allnet_log: UnsafeMutablePointer<allnet_log>? = nil
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var printedSendError = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        sessions = [MCSession]()
        createAllNetDir()
        self.xChat = XChat()
        self.xChat.initialize()
        startAllnet(application: application, firstCall: true)
        let minute = TimeInterval.init(60)
        application.setMinimumBackgroundFetchInterval(minute)
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                self.authorizationGranted = granted
            }
            UNUserNotificationCenter.current().delegate = self
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        } else {
            // https://stackoverflow.com/questions/41912386/using-unusernotificationcenter-for-ios-10
            // plus fixed anything the compiler suggested I fix
            application.registerUserNotificationSettings(UIUserNotificationSettings(types: UIUserNotificationType(rawValue: UIUserNotificationType.sound.rawValue | UIUserNotificationType.alert.rawValue |
                UIUserNotificationType.badge.rawValue), categories: nil))
        }
        application.applicationIconBadgeNumber = 0
        
        setPeer()
        UIApplication.shared.registerForRemoteNotifications()
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        return true
    }
    
    @objc func batteryChanged(){
        set_speculative_computation (UIDevice.current.batteryState != UIDevice.BatteryState.unplugged ? 0 : 1)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // enterBackground(caller: "appWRA")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        enterBackground(application: application, caller: "appDEB")
        debugToMaru(message: "applicationDidEnterBackground")
// self.notifyMessageReceived(contact: "application", message: "entered background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        startAllnet(application: application, firstCall: false)
        set_speculative_computation (UIDevice.current.batteryState != UIDevice.BatteryState.unplugged ? 0 : 1)
        print ("application entered foreground, \(application.applicationIconBadgeNumber) badges")
        application.applicationIconBadgeNumber = 0
        debugToMaru(message: "applicationWillEnterForeground")
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print ("application registered for remote notification, token \(deviceToken)")
        debugToMaru(message: "application registered for remote notification, token \(deviceToken)")
        for d in deviceToken {
            let s = String(format:"%02X", d)
            print ("\(s)", terminator: ":")
        }
        print ("")  // newline
        CHelper.send_push_request(deviceToken)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler:@escaping (UIBackgroundFetchResult)->Void) {
        let foreground = self.connected
        let fb = foreground ? "foreground" : "background"
        print ("\(fb) application received remote notification")
        debugToMaru(message: "\(fb) application received remote notification")
        //self.notifyMessageReceived(contact: "application in \(fb):", message: "remote notification")
        let messageIfAny = userInfo["message"] as? String
        let original = XChat.userMessagesReceived()
        if !foreground {
            startAllnet(application: application, firstCall: false)
            sleep (1)
        }
        if let message: String = messageIfAny {
            print ("message is \(message), \(message.count) bytes")
            let length = (message.count % 2 == 0) ? message.count / 2 : 0
            let values = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            let vptr = UnsafeMutableBufferPointer(start: values, count: length)
            var mcopy = message
            for i in 0..<length {
                let twoBytes = mcopy.prefix(2)
                vptr[i] = UInt8(twoBytes, radix: 16)!
                mcopy = String(mcopy.dropFirst(2))
            }
            // for e in 0..<length { print ("sending \(e): \(values[e])") }
            sendToAd(buffer: values, size: length)
            print ("sendToAd for remote notification complete")
        }
        let sleep_seconds = foreground ? 5 : 25
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(sleep_seconds)) {
            let final = XChat.userMessagesReceived()
            let result = final > original ? UIBackgroundFetchResult.newData : UIBackgroundFetchResult.noData
    //        self.notifyMessageReceived(contact: "final \(final)", message: "original \(original)")
            print ("final result of remote notification is \(final) >? \(original)")
            self.debugToMaru(message: "final result of remote notification is \(final) >? \(original)")
            completionHandler(result)
        }
    }

    @objc func notifyMessageReceived(contact: String, message: String){
        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            content.title = contact
            content.body = message
            content.sound = UNNotificationSound.default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "req", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
                DispatchQueue.main.async {
                    if UIApplication.shared.applicationState != .active {
                        UIApplication.shared.applicationIconBadgeNumber += 1
                    }
                }
            })
        }
    }
    
    func enterBackground(application: UIApplication, caller: String) {
        print("\(caller) entered background, connected is \(self.connected)")
        pcache_write()
        set_speculative_computation(0)
        self.shutdownAllnet()
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
    
    func shutdownAllnet() {
        objc_sync_enter(self)  // only one thread at a time
        defer{  objc_sync_exit(self)  }  // called when we exit the function
        if self.connected {
            print("shutdownAllnet actually performing the shutdown")
            pcache_write()
            self.xChat.disconnect()
            stop_allnet_threads()
            self.socket_counter = self.socket_counter + 1
            self.connected = false
        }
    }

    func startAllnet(application: UIApplication, firstCall: Bool) {
        objc_sync_enter(self)    // synchronize so only called by one thread at a time
        defer{  objc_sync_exit(self)  }  // called when we exit the function
        if self.connected {
            print ("startAllnet called, but already connected, doing nothing")
            return
        }
// esb 2021/08/10  I think this belongs in the code where we enter background, and can be simplified
//        var task = UIBackgroundTaskIdentifier.invalid
//        task = application.beginBackgroundTask {
//            if task != UIBackgroundTaskIdentifier.invalid {
//                let local_task = task
//                print("allnet task starting background task \(local_task)")
//                task = UIBackgroundTaskIdentifier.invalid
//                self.shutdownAllnet()
//                print("allnet task ending background task \(local_task)")
//                application.endBackgroundTask(local_task)
//            }
//        }
        if firstCall {
            allnet_log = init_log ("AppDelegate.m")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if firstCall || !self.connected {
                NSLog("calling astart_main\n")
                let args = ["allnet", nil]
                var pointer = args.map{Pointer(mutating: (($0 ?? "") as NSString).utf8String)}
                astart_main(1, &pointer)
                print("astart_main has completed")
                var success = false
                var repeatCount = 5 // try up to five times
                repeat {
                    sleep(1)
                    print("(re)connecting to ad")
                    success = self.xChat.connect()
                    repeatCount -= 1
                    if !success {
                        let call = firstCall ? "initialize" : "reconnect"
                        print("\(call) failed, count \(repeatCount)")
                    }
                } while (!success) && (repeatCount > 0)
                self.connected = success
                let call = firstCall ? "initialize" : "reconnect"
                let resString = success ? "success" : "failed"
                print("\(call) result is \(resString)")
            }
            // set up a connection to the allnet daemon that we can use to send and receive multipeer packets
            NSLog("(re)starting multipeer connection %d\n", self.socket_counter)
            self.mp_socket = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            let initial_socket_counter = self.socket_counter
            while initial_socket_counter == self.socket_counter {  // read the socket, forward messages to the peers
                var sa = sockaddr ()
                var sal = socklen_t(16)
                var buffer: [CChar] = Array(repeating: CChar(0), count: Int(ALLNET_MTU))
                let n = recvfrom (self.mp_socket, &buffer, Int(ALLNET_MTU), MSG_DONTWAIT, &sa, &sal)
                if (n <= 0) {
                    usleep(1000)
                } else {
                    self.sendSession(buffer: buffer, length: n)
                }
                self.sendKeepalive ()
            }
            // print("finished multipeer forwarding \(initial_socket_counter) != \(self.socket_counter)")
        }
        print("astart_main has been started")
    }

    func sendSession(buffer: [CChar], length: Int) {
        let send = Data(bytes: buffer, count: length)
        for i in 0..<self.sessions.count {
            let session = self.sessions[i]
            if (session.connectedPeers.count > 0) {
                try? session.send(send, toPeers: session.connectedPeers, with: .unreliable)
            }
        }
    }
    
    // send a packet to the local ad
    func sendToAd(buffer: UnsafeRawPointer, size: Int) {
        let slen = socklen_t(MemoryLayout<sockaddr_in>.size)
        var addr = self.mp_sin
        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto (self.mp_socket, buffer, Int(size), MSG_DONTWAIT, $0, slen)
            }
        }
        if (sent != size) {  // if returned -1, only print once
            if ((sent != -1) || (self.printedSendError == false)) {
                perror("AppDelegate.swift sendToAd for multipeer socket")
                NSLog("sent %d instead of %d\n", sent, size)
                if (sent == -1) {
                    self.printedSendError = true
                }
            }
        }
    }
    
    func sendKeepalive() {
        if allnet_time () <= self.last_sent + 5 {
            return;
        }
        self.last_sent = allnet_time()
        var size: UInt32 = 0;
        let buffer: UnsafeRawPointer = UnsafeRawPointer(keepalive_packet(&size))
        sendToAd (buffer:buffer, size:Int(size))
    }
    
    func setPeer(){
        let serverType = "allnet-p2p"
        currentPeerID = getPeer()
        advertiser = MCNearbyServiceAdvertiser(peer: currentPeerID, discoveryInfo: nil, serviceType: serverType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: currentPeerID, serviceType: serverType)
        browser.delegate = self
        NSLog("self.peerID %@, advertiser %@, browser %@\n", currentPeerID.displayName, advertiser.description, browser.description)
        browser.startBrowsingForPeers()
        NSLog("didFinishLaunching complete\n");
    }
    
    func getPeer() -> MCPeerID {
        let peerIDKey = "peerID"
        var result: MCPeerID? = nil
        do {
            if let peerIdData = UserDefaults.standard.data(forKey: peerIDKey) {
                result = try NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: peerIdData)
                // result = NSKeyedUnarchiver.unarchiveObject(with: peerIdData) as? MCPeerID
                NSLog("found peer ID %@\n", result!.displayName)
            }
        } catch { print(error) }
        
        if result == nil {
            let deviceName = UIDevice.current.name
            var buffer = [Int8](repeating:0, count: 10)
            random_string(&buffer, 11)
            let randomValue = String(utf8String: &buffer)
            let displayName = deviceName + ", unique " + randomValue!
            result = MCPeerID(displayName: displayName)
            NSLog("created peer ID %@\n", result!.description)
            do {
                let peerID = try  NSKeyedArchiver.archivedData(withRootObject: result!, requiringSecureCoding: false)
                // NSKeyedArchiver.archivedData(withRootObject: result!)
                let defaults = UserDefaults.standard
                defaults.setValue(peerID, forKey: peerIDKey)
                defaults.synchronize()
            } catch { print (error) }
        }
        return result!
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}

extension AppDelegate: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let session = MCSession(peer: currentPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        sessions.append(session)
        let timeoutTime: TimeInterval = 100
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: timeoutTime)
        NSLog("invited multipeer session %@, names are %@ < %@\n", session, peerID.displayName, currentPeerID.displayName)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if let index = sessions.firstIndex(where: { $0.connectedPeers.contains(peerID)}) {
            sessions.remove(at: index)
            NSLog("multipeer browser %@ removed lost peer %@\n", browser, peerID)
        } else {
            NSLog("multipeer browser %@ did not remove lost peer %@\n", browser, peerID)
        }
    }
}

extension AppDelegate: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("got multipeer invitation from %@\n", peerID)
        let session = MCSession(peer: currentPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        sessions.append(session)
        invitationHandler(true, session)
    }
}

extension AppDelegate: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        var message = "unknown"
        switch state {
        case .connected:
            sessions.append(session)
            message = "connected"
        case .notConnected:
            if let index = sessions.firstIndex(where: { $0.myPeerID == peerID}) {
                sessions.remove(at: index)
                NSLog("removing session %@ from sessions %@\n", session, sessions)
            }
            message = "not connected"
        case .connecting:
            message = "connecting"
        @unknown default:
            message = "unknown (really unknown!)"
        }
        NSLog("multipeer session %@ peer %@ changed state to %ld (%@)\n", session, peerID, state.rawValue, message)
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let length = data.count
        // NSLog("received %d bytes\n", length)
        let values = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        let vptr = UnsafeMutableBufferPointer(start: values, count: length)
        let send_size = data.copyBytes(to: vptr)
        sendToAd(buffer: values, size: send_size)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("multipeer session %@ did receive stream %@ with name %@ from peer %@\n", session, stream, streamName, peerID)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("multipeer session %@ did start %@ from %@ progress %@\n", session, resourceName, peerID, progress)
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("multipeer session %@ did finish %@ from %@ url %@ error %@\n", session.myPeerID.displayName, resourceName, peerID, localURL!.absoluteString, error!.localizedDescription)
    }

    func debugToMaru(message: String) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let dateString = formatter.string(from: date)
        let totalString = dateString + ": " + message + "\n"
        print ("debug message is \(totalString)")
        let s = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        var sin = sockaddr_in()
        sin.sin_len = UInt8(MemoryLayout.size(ofValue: sin))
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_port = UInt16(allnet_htons (Int32(23654)))
        sin.sin_addr.s_addr = inet_addr ("128.171.10.147")
        var sinCopy = sin   // not sure why this is needed, but it keeps the compiler happy
        let sent = totalString.withCString( { cstr -> Int in
            withUnsafePointer(to: &sinCopy) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto (s, cstr, strlen(cstr), MSG_DONTWAIT, $0, socklen_t(sin.sin_len))
                }
            }
        })
        if sent < 10 {
            print ("sent less than 10")
        }
        // sin.sin_addr.s_addr = inet_addr("128.171.10.147")
        close(s)
    }

}

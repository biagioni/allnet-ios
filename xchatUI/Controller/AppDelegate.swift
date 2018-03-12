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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var authorizationGranted = false
    var xChat: XChat!
    var firstCall =  true
    var currentPeerID: MCPeerID!
    var sessions: [MCSession]!
    var multipeer_read_queue_index: Int32 = 0
    var multipeer_write_queue_index: Int32 = 0
    var multipeer_queues_initialized: Int32 = 0
    var allnet_log: UnsafeMutablePointer<allnet_log>? = nil
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        sessions = [MCSession]()
        self.xChat = XChat()
        createAllNetDir()
        startAllnet(application: application, firstCall: true)
        sleep(1)
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                self.authorizationGranted = granted
            }
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        application.applicationIconBadgeNumber = 0
        
        setPeer()
        
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
        startAllnet(application: application, firstCall: false)
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
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber += 1
                }
            })
        }
    }
    
    func enterBackground(){
        acache_save_data()
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
    
    #if USE_ABLE_TO_CONNECT
        func ableToConnect() -> Bool {
            let sock = socket (AF_INET, SOCK_STREAM, IPPROTO_TCP)
            let sin = sockaddr_in()
            sin.sin_family = AF_INET
            sin.sin_addr.s_addr = inet_addr ("127.0.0.1")
            sin.sin_port = ALLNET_LOCAL_PORT
            if (connect (sock, &sin, sizeof (sin)) == 0) {
                close (sock)
                NSLog("allnet task still running, will not restart\n")
                return 1
            }
            NSLog("allnet task is not running\n")
            return 0
        }
    #endif /* USE_ABLE_TO_CONNECT */
    
    func startAllnet(application: UIApplication, firstCall: Bool) {
        if !firstCall {
            sleep (1)
            #if USE_ABLE_TO_CONNECT
                if ableToConnect() {
                    return
                }
                stop_allnet_threads()
                NSLog("calling stop_allnet_threads\n")
                sleep (1)
            #endif /* USE_ABLE_TO_CONNECT */
            NSLog("reconnecting xcommon to alocal\n")
            xChat.reconnect()
            sleep (1)
        }
        application.beginBackgroundTask {
             NSLog("allnet task ending background task (started by calling astart_main)\n")
            acache_save_data()
            self.xChat.disconnect()
        }
        if firstCall {
            allnet_log = init_log ("AppDelegate.m")
            NSLog("calling astart_main\n")
            DispatchQueue.global(qos: .userInitiated).async {
                let args = ["allnet", "-v", "default", nil]
                var pointer = args.map{Pointer(mutating: (($0 ?? "") as NSString).utf8String)}
                astart_main(3, &pointer)
                NSLog("astart_main has completed, starting multipeer thread\n")
                multipeer_queue_indices(&self.self.multipeer_read_queue_index, &self.multipeer_write_queue_index)
                self.multipeer_queues_initialized = 1
                // the rest of this is the multipeer thread that reads from ad and forwards to the peers
                let p = init_pipe_descriptor (self.allnet_log)
                add_pipe(p, self.multipeer_read_queue_index, "AppDelegate multipeer read pipe from ad")
                while (true) {  // read the ad queue, forward messages to the peers
                    var buffer: Pointer?
                    var from_pipe: Int32 = 0
                    var priority: UInt32 = 0
                    let n = receive_pipe_message_any(p, PIPE_MESSAGE_WAIT_FOREVER, &buffer, &from_pipe, &priority)
                    var debug_peers = 0;
                    for q in 0..<self.sessions.count {
                        let s = self.sessions[q]
                        debug_peers += s.connectedPeers.count
                    }
                    if debug_peers > 0{
                         NSLog("multipeer thread got %d-byte message from ad, forwarding to %d peers\n", n, debug_peers)
                    }
                    if from_pipe == self.multipeer_read_queue_index && n > 0 {
                        self.sendSession(buffer: buffer!, length: n)
                    }
                    if n > 0 && buffer != nil {
                        free(buffer)
                    }
                }
            }
            NSLog("astart_main has been started\n")
        }
    }
    func sendSession(buffer: UnsafeRawPointer, length: Int32) {
        let send = Data(bytes: buffer, count: Int(length))
        for i in 0..<self.sessions.count {
            let session = sessions[i]
            if (session.connectedPeers.count > 0) {
                try? session.send(send, toPeers: session.connectedPeers, with: .unreliable)
            }
        }
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
        multipeer_queue_indices(&multipeer_read_queue_index, &multipeer_write_queue_index);
        NSLog("didFinishLaunching complete\n");
    }
    
    func getPeer() -> MCPeerID {
        let peerIDKey = "peerID"
        var result: MCPeerID?
        if let peerIdData = UserDefaults.standard.data(forKey: peerIDKey){
            result = NSKeyedUnarchiver.unarchiveObject(with: peerIdData) as? MCPeerID
            NSLog("found peer ID %@\n", result!.displayName)
        }
        
        if result == nil {
            let deviceName = UIDevice.current.name
            var buffer = [Int8](repeating:0, count: 10)
            random_string(&buffer, 11)
            let randonValue = String(utf8String: &buffer)
            let displayName = deviceName + ", unique " + randonValue!
            result = MCPeerID(displayName: displayName)
            NSLog("created peer ID %@\n", result!.description)
            let peerID = NSKeyedArchiver.archivedData(withRootObject: result!)
            let defaults = UserDefaults.standard
            defaults.setValue(peerID, forKey: peerIDKey)
            defaults.synchronize()
        }
        return result!
    }
}

extension AppDelegate: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if peerID.displayName.localizedCompare(currentPeerID.displayName) == ComparisonResult.orderedAscending {
            let session = MCSession(peer: currentPeerID, securityIdentity: nil, encryptionPreference: .none)
            session.delegate = self
            sessions.append(session)
            let timeoutTime: TimeInterval = 100
            browser.invitePeer(currentPeerID, to: session, withContext: nil, timeout: timeoutTime)
            NSLog("invited multipeer session %@, names are %@ < %@\n", session, peerID.displayName, currentPeerID.displayName)
        }else{
            NSLog("did not invite multipeer session, names are %@ >= %@\n", currentPeerID.displayName, currentPeerID.displayName)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if let index = sessions.index(where: { $0.myPeerID == peerID}) {
            sessions.remove(at: index)
        }
        NSLog("multipeer browser %@ lost peer %@\n", browser, peerID)
    }
}

extension AppDelegate: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
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
            if let index = sessions.index(where: { $0.myPeerID == peerID}) {
                sessions.remove(at: index)
                NSLog("removing session %@ from sessions %@\n", session, sessions)
            }
            message = "not connected"
        case .connecting:
            message = "connecting"
        }
        NSLog("multipeer session %@ peer %@ changed state to %ld (%s)\n", session, peerID, state.rawValue, message)
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let length = data.count
        if (multipeer_queues_initialized == 1) {
            var values: UInt8? = nil
            data.copyBytes(to: &values!, count: length)
            var val: Int8 = Int8(values!)
            send_pipe_message_free (Int32(multipeer_write_queue_index), &val, UInt32(length), UInt32(ALLNET_PRIORITY_EPSILON), allnet_log)
        } else {
            NSLog("multipeer didReceiveData unable to forward packet, queue not initialized\n")
        }
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
}

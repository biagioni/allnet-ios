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
    // this socket and address are used to forward packets received from multipeer to ad and back
    var mp_socket: Int32 = -1
    let mp_sin: sockaddr_in = sockaddr_in (
        sin_len: __uint8_t (16),
        sin_family: sa_family_t (AF_INET),
        sin_port: UInt16(allnet_htons (Int32(ALLNET_PORT))),
        sin_addr: in_addr(s_addr: 0x7f000001),
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    var last_sent: UInt64 = 0
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
            UNUserNotificationCenter.current().delegate = self
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
                    if UIApplication.shared.applicationState != .active {
                        UIApplication.shared.applicationIconBadgeNumber += 1
                    }
                }
            })
        }
    }
    
    func enterBackground(){
        pcache_write()
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
            pcache_write()
            self.xChat.disconnect()
        }
        if firstCall {
            allnet_log = init_log ("AppDelegate.m")
            NSLog("calling astart_main\n")
            DispatchQueue.global(qos: .userInitiated).async {
                let args = ["allnet", "-v", "default", nil]
                var pointer = args.map{Pointer(mutating: (($0 ?? "") as NSString).utf8String)}
                astart_main(3, &pointer)
                // set up a connection to the allnet daemon that we can use to send and receive multipeer packets
                NSLog("astart_main has completed, starting multipeer connection\n")
                self.mp_socket = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                while (true) {  // read the socket, forward messages to the peers
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
            }
            NSLog("astart_main has been started\n")
        }
    }
    func sendSession(buffer: [CChar], length: Int) {
        let send = Data(bytes: buffer, count: length)
        for i in 0..<self.sessions.count {
            let session = sessions[i]
            if (session.connectedPeers.count > 0) {
                try? session.send(send, toPeers: session.connectedPeers, with: .unreliable)
            }
        }
    }
    
    func send_udp(buffer: UnsafeRawPointer, size: Int) {
        let slen = socklen_t(MemoryLayout<sockaddr_in>.size)
        var addr = self.mp_sin
        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto (self.mp_socket, buffer, Int(size), MSG_DONTWAIT, $0, slen)
            }
        }
        if (sent != size) {
            NSLog("sent ", sent, " instead of ", size, "\n")
        }
    }
    
    func sendKeepalive() {
        if allnet_time () <= self.last_sent + 5 {
            return;
        }
        self.last_sent = allnet_time()
        var size: UInt32 = 0;
        let buffer: UnsafeRawPointer = UnsafeRawPointer(keepalive_packet(&size))
        send_udp (buffer:buffer, size:Int(size))
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
        var result: MCPeerID?
        if let peerIdData = UserDefaults.standard.data(forKey: peerIDKey){
            result = NSKeyedUnarchiver.unarchiveObject(with: peerIdData) as? MCPeerID
            NSLog("found peer ID %@\n", result!.displayName)
        }
        
        if result == nil {
            let deviceName = UIDevice.current.name
            var buffer = [Int8](repeating:0, count: 10)
            random_string(&buffer, 11)
            let randomValue = String(utf8String: &buffer)
            let displayName = deviceName + ", unique " + randomValue!
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

extension AppDelegate: UNUserNotificationCenterDelegate {
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
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
        var values: UInt8? = nil
        data.copyBytes(to: &values!, count: length)
        var val: Int8 = Int8(values!)
        send_udp(buffer: &val, size: Int(length))
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

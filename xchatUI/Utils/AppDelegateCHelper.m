//
//  AppDelegateCHelper.m
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#include <unistd.h>
#include <sys/param.h>
#include <pthread.h>
#include <signal.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "util.h"
#include "packet.h"
#include "app_util.h"
#include "priority.h"
#include "allnet_log.h"
#import "pipemsg.h"
#import "AppDelegateCHelper.h"

#include <syslog.h>  


@interface AppDelegateCHelper()

@end

@implementation AppDelegateCHelper

extern void acache_save_data (void);
static int isSuspended = NO;
static int multipeer_read_queue_index = 0;
static int multipeer_write_queue_index = 0;
static int multipeer_queues_initialized = 0;
static struct allnet_log * allnet_log = NULL;

#ifdef USE_ABLE_TO_CONNECT
static int able_to_connect ()
{
    int sock = socket (AF_INET, SOCK_STREAM, IPPROTO_TCP);
    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr ("127.0.0.1");
    sin.sin_port = ALLNET_LOCAL_PORT;
    if (connect (sock, (struct sockaddr *) &sin, sizeof (sin)) == 0) {
        close (sock);
        NSLog(@"allnet task still running, will not restart\n");
        return 1;
    }
    NSLog(@"allnet task is not running\n");
    return 0;
}
#endif /* USE_ABLE_TO_CONNECT */

- (void) start_allnet:(UIApplication *) application start_everything:(BOOL)first_call {
    static UIBackgroundTaskIdentifier task;
    if (! first_call) {   // no point in calling until after we start allnet
        sleep (1);          // give time to restart
#ifdef USE_ABLE_TO_CONNECT
        if (able_to_connect ())  // daemons should still be running, sockets should still be open
            return;
        extern void stop_allnet_threads ();  // from astart.c
        NSLog(@"calling stop_allnet_threads\n");
        stop_allnet_threads ();
        sleep (1);
#endif /* USE_ABLE_TO_CONNECT */
        NSLog(@"reconnecting xcommon to alocal\n");
        [self.xChat reconnect];
        sleep (1);
    }
    // see https://developer.apple.com/library/ios/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/BackgroundExecution/BackgroundExecution.html#//apple_ref/doc/uid/TP40007072-CH4-SW1
    task = [application beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"allnet task ending background task (started by calling astart_main)\n");
        acache_save_data ();
        [self.xChat disconnect];
        isSuspended = 1;
        [application endBackgroundTask:task];
        task = UIBackgroundTaskInvalid;
    }];
    if (first_call) {
        allnet_log = init_log ("AppDelegate.m");
        NSLog(@"calling astart_main\n");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            extern int astart_main (int argc, char ** argv);
            char * args [] = { "allnet", "-v", "default", NULL };
            astart_main(3, args);
            NSLog(@"astart_main has completed, starting multipeer thread\n");
            // allow reading from the multipeer socket
            extern void multipeer_queue_indices (int * rpipe, int * wpipe);
            multipeer_queue_indices(&multipeer_read_queue_index, &multipeer_write_queue_index);
            multipeer_queues_initialized = 1;
            // the rest of this is the multipeer thread that reads from ad and forwards to the peers
            pd p = init_pipe_descriptor (allnet_log);
            add_pipe(p, multipeer_read_queue_index, "AppDelegate multipeer read pipe from ad");
            while (true) {  // read the ad queue, forward messages to the peers
                char * buffer = NULL;
                int from_pipe;
                unsigned int priority;
                int n = receive_pipe_message_any(p, PIPE_MESSAGE_WAIT_FOREVER, &buffer, &from_pipe, &priority);
                int debug_peers = 0;
                for (int q = 0; q < self.sessions.count; q++) {
                    MCSession * s = (MCSession *) self.sessions [q];
                    debug_peers += s.connectedPeers.count;
                }
                if (debug_peers > 0) NSLog(@"multipeer thread got %d-byte message from ad, forwarding to %d peers\n", n, debug_peers);
                if ((from_pipe == multipeer_read_queue_index) && (n > 0)) {
                    [self sendSession:buffer length:n];
                }
                if ((n > 0) && (buffer != NULL))
                    free (buffer);
            }
        });
        NSLog(@"astart_main has been started\n");
    }
}

-(void) acacheSaveData {
    acache_save_data();
}

- (void) setPeer {
    NSString * servType = @"allnet-p2p";
    self.peerID = [self getPeer];
    // http://nshipster.com/multipeer-connectivity/
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID discoveryInfo:nil serviceType:servType];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID serviceType:servType];
    self.browser.delegate = self;
    NSLog(@"self.peerID %@, advertiser %@, browser %@\n", self.peerID, self.advertiser, self.browser);
    self.sessions = [[NSMutableArray alloc] initWithCapacity:1000];
    [self.browser startBrowsingForPeers];
    
    // start reading from the multipeer socket
    extern void multipeer_queue_indices (int * rpipe, int * wpipe);
    multipeer_queue_indices(&multipeer_read_queue_index, &multipeer_write_queue_index);
    
    NSLog(@"didFinishLaunching complete\n");
}

- (MCPeerID *)getPeer {
    // https://developer.apple.com/documentation/multipeerconnectivity/mcpeerid?language=objc
    // overview: https://developer.apple.com/documentation/multipeerconnectivity?language=objc
    // see also https://www.appcoda.com/intro-multipeer-connectivity-framework-ios-programming/
    NSString * peerIDKey = @"peerID";
    bool deleteEarlierIDs = NO;  // used for debugging only
    if (deleteEarlierIDs) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:peerIDKey];
        [defaults synchronize];
    }
    NSData *peerIDData = [[NSUserDefaults standardUserDefaults] dataForKey:peerIDKey];
    // load it from the persistent store if possible
    MCPeerID * result = [NSKeyedUnarchiver unarchiveObjectWithData:peerIDData];
    NSLog(@"found peer ID %@\n", result);
    if (result == nil) {
        NSString * deviceName = [UIDevice currentDevice].name;
        char buffer [20] = ", unique ";
        random_string (buffer + 9, sizeof (buffer) - 9);
        NSString* displayName = [deviceName stringByAppendingString:[[NSString alloc] initWithUTF8String:buffer]];
        result = [[MCPeerID alloc] initWithDisplayName:displayName];
        NSLog(@"created peer ID %@\n", result);
        // make it persistent, otherwise we create lots of peer IDs which can be confusing
        peerIDData = [NSKeyedArchiver archivedDataWithRootObject:result];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:peerIDData forKey:peerIDKey];
        [defaults synchronize];
    }
    return result;
}

- (void) createAllNetDir {
    // make sure Application Support folder exists
    NSError * error = nil;
    NSURL *applicationSupportDirectory = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                                inDomain:NSUserDomainMask
                                                                       appropriateForURL:nil
                                                                                  create:YES
                                                                                   error:&error];
    if (error) {
        NSLog(@"unable to create allnet application dir, %@", error);
        return;
    }
    
    NSURL *allnetDir = [applicationSupportDirectory URLByAppendingPathComponent:@"allnet" isDirectory:YES];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:[allnetDir path]
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error]) {
        NSLog(@"unable to create allnet dir, %@\n", error);
        return;
    }
    // tell iTunes not to back up the contents of this directory
    BOOL success = [allnetDir setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"error %@ excluding %@ from backup\n", error, allnetDir);
    }
    NSLog(@"directory %@ should exist, please check\n", allnetDir);
    char buf [MAXPATHLEN + 1];
    getcwd(buf, sizeof(buf));
    NSLog(@"pwd is %s\n", buf);
    char * src = malloc(allnetDir.path.length + 1);
    strcpy(src, allnetDir.path.UTF8String);
    NSLog(@"src is %s, path %s\n", src, allnetDir.path.UTF8String);
    char * toRemove = "/Library/Application Support/allnet";
    size_t slen = strlen(src);
    size_t rlen = strlen(toRemove);
    NSLog(@"comparing %s to %s, %zd %zd\n", src + (slen - rlen), toRemove, slen, rlen);
    if ((slen > rlen) && (memcmp (src + (slen - rlen), toRemove, rlen) == 0))
        src [slen - rlen] = '\0';
    chdir(src);
    NSLog(@"pwd now is %s (%s)\n", getcwd(buf, sizeof(buf)), src);
}

- (void)sendSession:(char *)buffer length:(int)n {
    NSData * send = [[NSData alloc] initWithBytes:buffer length:n];
    for (int i = 0; i < self.sessions.count; i++) {
        MCSession * session = (MCSession *) (self.sessions [i]);
        if (session.connectedPeers.count > 0) {
            NSError * err = nil;
            [session sendData:send toPeers:session.connectedPeers withMode:MCSessionSendDataUnreliable error:&err];
            // NSLog(@"multipeer sent [%d]/%lu %d bytes to peers %@\n", i, (unsigned long)self.sessions.count, n, session.connectedPeers);
        }
    }
}

// Found a nearby advertising peer.
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info {
    if ([peerID.displayName localizedCompare:self.peerID.displayName] == NSOrderedAscending) {
        // https://peterfennema.nl/ios-multipeer-2/ -- only invite if the peer has a name less than ours
        // note that we made the names almost-certainly-unique in getPeer
        MCSession * session = [[MCSession alloc] initWithPeer:self.peerID];
        session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        session.delegate = self;
        [self.sessions addObject:session];
        NSTimeInterval timeoutTime = 100;  // 100 second timeout -- not sure what number is reasonable here
        [self.browser invitePeer:peerID toSession:session withContext:nil timeout:timeoutTime];
        NSLog(@"invited multipeer session %@, names are %@ < %@\n", session, peerID.displayName, self.peerID.displayName);
    } else {
        NSLog(@"did not invite multipeer session, names are %@ >= %@\n", peerID.displayName, self.peerID.displayName);
    }
}

// A nearby peer has stopped advertising.
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    NSLog(@"multipeer browser %@ lost peer %@\n", browser, peerID);
}

// MCNearbyServiceAdvertiserDelegate

// http://nshipster.com/multipeer-connectivity/
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    MCSession * session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
    session.delegate = self;
    [self.sessions addObject:session];
    NSLog(@"multipeer advertiser (%@, %@ (> %@), %@) created session %@\n", advertiser, peerID.displayName, self.peerID.displayName, invitationHandler, session);
    invitationHandler (YES, session);
}

- (instancetype)initWithPeer:(MCPeerID *)myPeerID discoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info serviceType:(NSString *)serviceType {
    NSLog(@"multipeer initWithPeer %@, info %@, service %@\n", myPeerID, info, serviceType);
    return self;
}

// The methods -startAdvertisingPeer and -stopAdvertisingPeer are used to
// start and stop announcing presence to nearby browsing peers.
- (void)startAdvertisingPeer {
    NSLog(@"multipeer startAdvertisingPeer\n");
}

- (void)stopAdvertisingPeer {
    NSLog(@"multipeer stopAdvertisingPeer\n");
}

// MCSessionDelegate

// Remote peer changed state.
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    const char * sname =
    ((state == MCSessionStateNotConnected) ? "not connected" :
     ((state == MCSessionStateConnecting) ? "connecting" :
      ((state == MCSessionStateConnected) ? "connected" : "unknown")));
    NSLog(@"multipeer session %@ peer %@ changed state to %ld (%s)\n", session, peerID, (long)state, sname);
    if (state == MCSessionStateNotConnected) {
        NSLog(@"removing session %@ from sessions %@\n", session, self.sessions);
        [self.sessions removeObject:session];
        NSLog(@"removed, new sessions is %@\n", self.sessions);
    } else if (state == MCSessionStateConnected) {
        [self.sessions addObject:session];
    }
}

// Received data from remote peer.
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    int len = (int)data.length;
    // NSLog(@"multipeer session %@ did receive data (%d bytes) from peer %@\n", session, len, peerID);
    if (multipeer_queues_initialized) {   // send the message to ad
        char * buffer = memcpy_malloc (data.bytes, len, "received data buffer");
        send_pipe_message_free (multipeer_write_queue_index, buffer, len, ALLNET_PRIORITY_EPSILON, allnet_log);
    } else {
        NSLog(@"multipeer didReceiveData unable to forward packet, queue not initialized\n");
    }
}

// Received a byte stream from remote peer.
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    NSLog(@"multipeer session %@ did receive stream %@ with name %@ from peer %@\n", session, stream, streamName, peerID);
    
}

// Start receiving a resource from remote peer.
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"multipeer session %@ did start %@ from %@ progress %@\n", session, resourceName, peerID, progress);
}

// Finished receiving a resource from remote peer and saved the content
// in a temporary location - the app is responsible for moving the file
// to a permanent location within its sandbox.
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(nullable NSError *)error {
    NSLog(@"multipeer session %@ did finish %@ from %@ url %@ error %@\n", session, resourceName, peerID, localURL, error);
}


@end

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

- (void)startAdvertisingPeer {
    NSLog(@"multipeer startAdvertisingPeer\n");
}

- (void)stopAdvertisingPeer {
    NSLog(@"multipeer stopAdvertisingPeer\n");
}


@end


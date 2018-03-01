//
//  AppDelegateCHelper.h
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/15/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#ifndef AppDelegateCHelper_h
#import <UIKit/UIKit.h>
#import "XChat.h"
#import "MultipeerConnectivity/MultipeerConnectivity.h"
#define AppDelegateCHelper_h

@interface AppDelegateCHelper : UIResponder <MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate>
@property (nonatomic, strong) XChat * xChat;
@property (nonatomic, strong) MCPeerID * peerID;
@property (nonatomic, strong) MCNearbyServiceAdvertiser * advertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser * browser;
@property (nonatomic, strong) NSMutableArray * sessions;
- (void) createAllNetDir;
-(void) acacheSaveData;

- (void) start_allnet:(UIApplication *) application start_everything:(BOOL)first_call;
- (void) setPeer;
@end
#endif /* AppDelegateCHelper_h */

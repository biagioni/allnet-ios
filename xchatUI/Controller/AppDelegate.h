//
//  AppDelegate.h
//  xchat UI
//
//  Created by e on 2015/04/25.
//  Copyright (c) 2015 allnet. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XChat.h"
#import "ConversationUITextView.h"
#import "ContactsUITableViewController.h"
#import "MultipeerConnectivity/MultipeerConnectivity.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) XChat * xChat;
@property (nonatomic, strong) ConversationUITextView * conversation;
@property (nonatomic, strong) ContactsUITableViewController * tvc;
@property (nonatomic, strong) MCPeerID * peerID;
@property (nonatomic, strong) MCNearbyServiceAdvertiser * advertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser * browser;
@property (nonatomic, strong) NSMutableArray * sessions;

@property UIApplication * my_app;

- (void) setXChatValue:(XChat *)xChat;
- (void) setConversationValue:(ConversationUITextView *)conversation;
- (void) setContactsUITVC: (ContactsUITableViewController *) tvc;
- (void) batteryChangedNotification;
- (void) notifyMessageReceived:(NSString *) contact message: (NSString *) msg;
- (BOOL) appIsInForeground;

@end


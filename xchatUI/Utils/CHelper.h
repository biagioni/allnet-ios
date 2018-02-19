//
//  CHelper.h
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#ifndef CHelper_h
#define CHelper_h

@interface CHelper : NSObject
@property char * xcontact;

- (void) newMessage: (NSString *) contact : (UITextView*) conversation : (BOOL) conversationIsDisplayed : (NSMutableDictionary*) contactsWithNewMessages : (UIViewController*) vc : (UITableView*) tableView;

- (NSMutableArray *)getMessages;
- (void) initialize: (int) sock : (NSString *) contact;
- (void)sendMessage:(NSString*) message;

- (void) notifyConversationChange: (BOOL) beingDisplayed : (BOOL) conversationIsDisplayed : (UITextView*) conversation : (UIViewController*) vc : (UITableView*) tableView : (NSMutableDictionary*) contactsWithNewMessages;
@end



#endif /* CHelper_h */

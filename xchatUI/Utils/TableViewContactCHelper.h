//
//  TableViewContactCHelper.h
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#ifndef TableViewContactCHelper_h
#define TableViewContactCHelper_h

@interface TableViewContactCHelper : NSObject

- (void) newMessage: (NSString *) contact : (UITextView*) conversation : (BOOL) conversationIsDisplayed : (NSMutableDictionary*) contactsWithNewMessages : (UIViewController*) vc : (UITableView*) tableView;


- (void) notifyConversationChange: (BOOL) beingDisplayed : (BOOL) conversationIsDisplayed : (UITextView*) conversation : (UIViewController*) vc : (UITableView*) tableView : (NSMutableDictionary*) contactsWithNewMessages;

@end



#endif /* TableViewContactCHelper_h */

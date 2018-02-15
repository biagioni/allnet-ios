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

-(NSInteger) getRowsCount: (NSMutableArray*) contacts :  (BOOL) displaySettings;

- (UITableViewCell *)tableView:(UITableView *)tableView :(NSIndexPath *)indexPath : (NSMutableArray*) contacts : (BOOL) displaySettings : (NSMutableArray*) hiddenContacts : (NSMutableDictionary*) contactsWithNewMessages : (UIViewController*) vc;

@end



#endif /* TableViewContactCHelper_h */

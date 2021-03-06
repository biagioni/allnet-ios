//
//  CHelper.h
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#ifndef CHelper_h
#import "MessageModel.h"
#define CHelper_h

@interface CHelper : NSObject
@property char * xcontact;

- (NSMutableArray *)getMessages;
- (NSMutableArray *)allMessages;
- (void) initialize: (int) sock : (NSString *) contact;
- (MessageModel*)sendMessage:(NSString*) message;
- (NSString *) getMessagesSize;
+ (NSString *) generateRandomKey;
+ (NSString *) getKeyFor: (const char *) contact;
- (uint64_t) last_time_read: (const char *) contact;
+ (BOOL) exchange_is_complete: (const char *) contact;
+ (void) send_push_request: (NSData*) device_token;
@end



#endif /* CHelper_h */

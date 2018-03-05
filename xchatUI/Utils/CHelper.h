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
- (void) initialize: (int) sock : (NSString *) contact;
- (MessageModel*)sendMessage:(NSString*) message;
- (NSString *) getMessagesSize;
+ (NSString *) generateRandoKey;
+ (NSString *) getKeyFor: (const char *) contact;
@end



#endif /* CHelper_h */

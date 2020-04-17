//
//  Message.h
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/16/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#ifndef MessageModel_h
#define MessageModel_h

@interface MessageModel : NSObject
@property NSString *message;
@property int msg_type;
@property NSString *dated;
@property NSString * received;
@property int message_has_been_acked;
@property int *msize;
@property int *seq;
@property int *next;
@property int prev_missing;
@property uint64_t sent_time;
@property uint64_t rcvd_ackd_time;
@property NSString * contact_name;     // if received as part of a group message, the name of the sender
@property NSMutableSet * group_sent;   // if sent to a group, the individuals to whom went
@property NSMutableSet * group_acked;  // if sent to a group, the contact name as key refers to value nil if not acked, and some other value if acked
@end
#endif /* MessageModel_h */

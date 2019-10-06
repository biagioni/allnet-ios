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
@property uint64_t rcvd_ackd_time;
@end
#endif /* MessageModel_h */

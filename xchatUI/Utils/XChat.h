//
//  XChatSocket.h
//  xchat UI
//
//  Created by e on 2015/05/22.
//  Copyright (c) 2015 allnet. All rights reserved.
//

#ifndef xchat_UI_XChat_h
#define xchat_UI_XChat_h

#import <Foundation/Foundation.h>

@interface XChat : NSObject

- (void) initialize;
- (void) disconnect;
- (void) reconnect;

- (void) setMessageVM:(NSObject *)object;
- (void) setContactVM:(NSObject *)object;
- (void) setMoreVM:(NSObject *)object;
- (void) setKeyVM:(NSObject *)object;

- (void) requestNewContact:(NSString *)contact
                   maxHops:(NSUInteger) hops
                   secret1:(NSString *) s1
           optionalSecret2:(NSString *) s2;

- (void) requestKey:(NSString *)contact maxHops: (NSUInteger) hops;

- (int) getSocket;

- (void) removeNewContact: (NSString *) contact;
- (void) resendKeyForNewContact: (NSString *) contact;
- (void) startTrace: (BOOL) wide_enough maxHops: (NSUInteger) hops showDetails: (BOOL) details;

- (void) completeExchange: (NSString *) contact;
// returns the contents of the exchange file, if any: hops\nsecret1\n[secret2\n]
- (NSString *) incompleteExchangeData: (NSString *) contact;
- (void) unhideContact: (NSString *) contact;

@end


#endif

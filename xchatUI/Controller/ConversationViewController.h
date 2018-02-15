//
//  ConversationViewController.h
//  xchat UI
//
//  Created by e on 2015/07/06.
//  Copyright (c) 2015 allnet. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ConversationViewController : UIViewController

- (void)notifyChange: (UIViewController *) conversation;

#define TEXTVIEWSIZE    1000  // maximum size of conversationuitextview

@end

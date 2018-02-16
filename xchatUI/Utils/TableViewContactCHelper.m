//
//  TableViewContactCHelper.m
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "keys.h"
#import "TableViewContactCHelper.h"
#import "ConversationUITextView.h"
#import "SettingsViewController.h"
#include "util.h"
#import "allnet_xchat-Swift.h"
#import "AppDelegate.h"


@interface TableViewContactCHelper()

@end

@implementation TableViewContactCHelper : NSObject

- (void)contactButtonClicked:(id) source : (NSMutableArray*) contacts : (UILabel*) contactName : (ConversationUITextView*) conversation : (NSMutableDictionary*) contactsWithNewMessages : (UITableView*) tableView {
    UIButton * button = (UIButton *) source;
    NSString * contact = nil;
    contact = [contacts objectAtIndex:button.tag];
    NSLog(@"in contactButtonClicked, text %@, contact %@\n", button.currentTitle, contact);
    if (contactName != nil) {
        contactName.text = contact;
        [self displayingContact:contact :contactsWithNewMessages :tableView];
        if (conversation != nil) {
            [conversation displayContact:contact];
            //self.tabBarController.selectedIndex = 1;
        }
    }
}

- (void)editButtonClicked:(id) source : (NSMutableArray*) contacts : (NSMutableArray*) hiddenContacts : (UIStoryboard*) storyboard : (UIViewController*) vc : (UILabel*) contactName : (NSMutableDictionary*) contactsWithNewMessages : (UITableView*) tableView {
    UIButton * button = (UIButton *) source;
    NSLog(@"in editButtonClicked, source %@, tag %d\n", source, (int)button.tag);
    NSString * contact = nil;
    if (button.tag < [contacts count])
        contact = [contacts objectAtIndex:button.tag];
    else if (button.tag < ([contacts count] + [hiddenContacts count]))
        contact = [hiddenContacts objectAtIndex:(button.tag - [contacts count])];
    else
        NSLog(@"error in ButtonClicked, tag %d, lengths %d %d, ignoring\n", (int)button.tag, (int)[contacts count], (int)[hiddenContacts count]);
    NSLog(@"in editButtonClicked, text %@, contact %@\n", button.currentTitle, contact);
    SettingsViewController * next = nil;
    if (next == nil)
        next = [storyboard instantiateViewControllerWithIdentifier:@"SettingsViewController"];
    if ((contact != nil) && (next != nil)) {
        [next initialize:strcpy_malloc (contact.UTF8String, "editButtonClicked")];
        [vc presentViewController:next animated:NO completion:nil];
        contactName.text = contact;
        [self displayingContact:contact :contactsWithNewMessages :tableView];
    }
}

- (void)settingsButtonClicked:(id) source :  (BOOL) displaySettings : (UITableView*) tableView{
    displaySettings = ! displaySettings;
    [tableView reloadData];
    NSLog(@"settings button clicked, %d\n", displaySettings);
}

// if n is 0, sets to zero.  Otherwise, adds n (positive or negative) to the current badge number
- (void) addToBadgeNumber: (NSInteger) n {
    UIApplication * app = [UIApplication sharedApplication];
    if (n == 0) {
        app.applicationIconBadgeNumber = 0;
    } else {
        app.applicationIconBadgeNumber = app.applicationIconBadgeNumber + n;
    }
    NSLog(@"icon badge number is now %ld\n", (long)app.applicationIconBadgeNumber);
}

- (void) displayingContact: (NSString *) contact : (NSMutableDictionary*) contactsWithNewMessages : (UITableView*) tableView {
    if ([contactsWithNewMessages objectForKey:contact] != nil) {
        NSNumber * count = [contactsWithNewMessages objectForKey:contact];
        if (count.integerValue > 0) {
            [self addToBadgeNumber: (- (int)count.integerValue)];
        }
        [contactsWithNewMessages removeObjectForKey:contact];
        [tableView reloadData];
    }
}

// is the conversation being displayed or hidden?
- (void) notifyConversationChange: (BOOL) beingDisplayed : (BOOL) conversationIsDisplayed : (ConversationUITextView*) conversation : (ContactListVC*) vc : (UITableView*) tableView : (NSMutableDictionary*) contactsWithNewMessages {
    conversationIsDisplayed = beingDisplayed;
    // if displayed, remove any notifications for the contact being displayed
    if ((beingDisplayed) && (conversation != nil) && ([conversation selectedContact] != nil)) {
        [self displayingContact:[conversation selectedContact] :contactsWithNewMessages :tableView];
        [conversation displayContact:[conversation selectedContact]];
    }
}

// when the interface is displayed, note that this contact has a new message
- (void) newMessage: (NSString *) contact : (ConversationUITextView*) conversation : (BOOL) conversationIsDisplayed : (NSMutableDictionary*) contactsWithNewMessages : (ContactListVC*) vc : (UITableView*) tableView {
    // selectedContact may be nil, contact should not be nil, so use [contact isEqual:]
    BOOL sameAsConversation = ([contact isEqual:[conversation selectedContact]]);
    BOOL contactIsDisplayed = (conversationIsDisplayed && sameAsConversation);
    NSLog(@"new message for contact %@, displayed %d %d\n", contact, sameAsConversation, contactIsDisplayed);

    AppDelegate * appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    if ((! contactIsDisplayed) || (! [appDelegate appIsInForeground])) {   // add the notification
        NSNumber * previous = [contactsWithNewMessages objectForKey:contact];
        NSNumber * next = nil;
        if (previous == nil)
            next = [[NSNumber alloc] initWithInt: 1];
        else
            next = [[NSNumber alloc] initWithInt:((int)previous.integerValue + 1)];
        [contactsWithNewMessages setObject:next forKey:contact];
        [vc setContacts];   // refresh the contacts list
        [tableView reloadData];
        [self addToBadgeNumber:1];
    } else {  // this contact is already displayed, update the contents
        [conversation displayContact: contact];
    }
}
@end


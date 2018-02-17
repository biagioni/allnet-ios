//
//  CHelper.m
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/14/18.
//  Copyright © 2018 allnet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CHelper.h"
#import "ConversationUITextView.h"
#import "SettingsViewController.h"
#import "allnet_xchat-Swift.h"
#import "AppDelegate.h"
#import "MessageModel.h"

#include <sys/stat.h>
#include <pthread.h>
#include "packet.h"
#include "util.h"
#include "store.h"
#include "message.h"
#include "keys.h"
#include "xcommon.h"


@interface CHelper()
@property int sock;
@property uint64_t newMessagesFrom;

@end

@implementation CHelper : NSObject

- (void) initialize: (int) sock : (NSString *) contact {
    self.sock = sock;
    self.xcontact = strcpy_malloc (contact.UTF8String, "ConversationUITextView initialize contact");
    self.newMessagesFrom = last_time_read (self.xcontact);
    update_time_read (contact.UTF8String);
}

- (NSMutableArray *)getMessages {
  NSMutableArray * result_messages = [[NSMutableArray alloc] initWithCapacity:1000];
    keyset * k;
    int nk = all_keys (self.xcontact, &k);
    for (int ik = 0; ik < nk; ik++) {
        struct msg_iter * iter = start_iter (self.xcontact, k [ik]);
        if (iter != NULL) {
            uint64_t seq;
            uint64_t time = 0;
            uint64_t rcvd_time = 0;
            int tz_min;
            char ack [MESSAGE_ID_SIZE];
            char * message = NULL;
            int msize;
            int next = prev_message(iter, &seq, &time, &tz_min, &rcvd_time, ack, &message, &msize);
            while (next != MSG_TYPE_DONE) {
                BOOL inserted = false;
                if ((next == MSG_TYPE_RCVD) || (next == MSG_TYPE_SENT)) {  // ignore acks
                    struct message_store_info mi;
                    if (message != NULL) {
                        mi.message = message;
                        mi.msize = msize;
                        mi.seq = seq;
                        mi.time = time;
                        mi.tz_min = tz_min;
                        mi.msg_type = next;
                        mi.message_has_been_acked = 0;
                        mi.prev_missing = 0;
                        if ((next == MSG_TYPE_SENT) &&
                            (is_acked_one(self.xcontact, k [ik], seq, NULL)))
                            mi.message_has_been_acked = 1;
                        NSObject * mipObject = [NSValue value:(&mi)
                                                 withObjCType:@encode(struct message_store_info)];
                        for (long i = (long)result_messages.count - 1; ((i >= 0) && (! inserted)); i--) {
                            struct message_store_info mi_from_array;
                            [(result_messages [i]) getValue:&mi_from_array];
                            if (mi.time <= mi_from_array.time) {  // insert here
                                [result_messages insertObject:mipObject atIndex:i + 1];
                                inserted = true;
                            }
                        }
                        if (! inserted) {  // should save it at the very beginning
                            [result_messages insertObject:mipObject atIndex:0];
                            inserted = true;
                        }
                    }
                }
                if ((! inserted) && (message != NULL))
                    free(message);
                message = NULL;
                next = prev_message(iter, &seq, &time, &tz_min, &rcvd_time, ack, &message, &msize);
            }
            free_iter(iter);
        }
    }
    if (nk > 0)  // release the storage for the keys
        free (k);
    uint64_t last_seq = 0;
    NSValue * last_received = NULL;
    for (NSValue * obj in result_messages) {  // add information about missing messages
        struct message_store_info mi;
        [obj getValue:&mi];
        if (mi.msg_type == MSG_TYPE_RCVD) {
            if ((last_seq != 0) && (last_received != NULL) &&
                (mi.seq + 1 < last_seq)) {
                struct message_store_info last_struct;
                [last_received getValue:&last_struct];
                last_struct.prev_missing = (last_seq - mi.seq - 1);
            }
            last_received = obj;
            last_seq = mi.seq;
        }
    }
    NSMutableArray * converted_messages = [[NSMutableArray alloc] initWithCapacity:[result_messages count]];
    for (NSValue * obj in result_messages) {  // create a bubble for each message
        struct message_store_info mi;
        [obj getValue:&mi];
        @try {   // initWithUTF8String will fail if the string is not valid UTF8
            BOOL is_new = mi.rcvd_ackd_time + (24 * 60 * 60) >= self.newMessagesFrom;
            MessageModel *model = [[MessageModel alloc] init];
            model.message = [[NSString alloc] initWithUTF8String:mi.message];
            model.msg_type = mi.msg_type;
            model.dated = basicDate(mi.time, mi.tz_min);
            model.message_has_been_acked = mi.message_has_been_acked;
            [converted_messages addObject:model];
            //[self drawBubble:[[NSString alloc] initWithUTF8String:mi.message] msg_type:mi.msg_type is_acked:mi.message_has_been_acked is_new:is_new context:context time:mi.time tzMin: mi.tz_min];
        } @catch (NSException *e) {
            NSLog(@"message %s is not valid UTF8, ignoring\n", mi.message);
        }
        free ((void *)mi.message);
    }
    
    return converted_messages;
}

static NSString * basicDate (uint64_t time, int tzMin) {
    // objective C time begins on January 1st, 2001.  allnet time begins on January 1st, 2000.
    uint64_t unixTime = time + ALLNET_Y2K_SECONDS_IN_UNIX;
    NSDate * date = [[NSDate alloc] initWithTimeIntervalSince1970:unixTime];
    // date formatter code from https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html#//apple_ref/doc/uid/TP40002369-SW1
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    NSString * dateString = [dateFormatter stringFromDate:date];
    if (local_time_offset() != tzMin) {
        // some of this code from cutil.c
        int delta = tzMin - local_time_offset();
        while (delta < 0)
            delta += 0x10000;  // 16-bit value
        if (delta >= 0x8000)
            delta = 0x10000 - delta;
        NSString * offset = [[NSString alloc] initWithFormat:@" (%+d:%d)", delta / 60, delta % 60];
        [dateString stringByAppendingString:offset];
    }
    dateString = [dateString stringByAppendingString:@"\n"];
    return dateString;
}

static int local_time_offset ()
{
    time_t now = time (NULL);
    
    struct tm now_ltime_tm;
    localtime_r (&now, &now_ltime_tm);
    struct tm gtime_tm;
    gmtime_r (&now, &gtime_tm);
    /*
     printf ("local time %s", asctime (&now_ltime_tm));
     printf ("   gm time %s", asctime (&gtime_tm));
     printf ("local time %d:%02d:%02d, gm time %d:%02d:%02d\n",
     now_ltime_tm.tm_hour, now_ltime_tm.tm_min, now_ltime_tm.tm_sec,
     gtime_tm.tm_hour, gtime_tm.tm_min, gtime_tm.tm_sec);
     printf ("local time offset %d\n", delta_minutes (&now_ltime_tm, &gtime_tm));
     */
    return (delta_minutes (&now_ltime_tm, &gtime_tm));
}

static int delta_minutes (struct tm * local, struct tm * gm)
{
    int delta_hour = local->tm_hour - gm->tm_hour;
    if (local->tm_wday == ((gm->tm_wday + 8) % 7)) {
        delta_hour += 24;
    } else if (local->tm_wday == ((gm->tm_wday + 6) % 7)) {
        delta_hour -= 24;
    } else if (local->tm_wday != gm->tm_wday) {
        printf ("assertion error: weekday %d != %d +- 1\n",
                local->tm_wday, gm->tm_wday);
        exit (1);
    }
    int delta_min = local->tm_min - gm->tm_min;
    if (delta_min < 0) {
        delta_hour -= 1;
        delta_min += 60;
    }
    int result = delta_hour * 60 + delta_min;
    /*
     printf ("delta minutes is %02d:%02d = %d\n", delta_hour, delta_min, result);
     */
    return result;
}


//- (void)assignContentForContact {
//    struct message_store_info * messages = NULL;
//    int messages_used = 0;
//    int messages_allocated = 0;
//    NSMutableArray * result_messages = [[NSMutableArray alloc] initWithCapacity:1000];
//    list_all_messages (self.xcontact, &messages, &messages_allocated, &messages_used);
//    if (messages_used > 0) {
//        for (int i = 0; i < messages_used; i++) {
//            [self addMessageToView:(messages + (messages_used - i - 1)) time:self.newMessagesFrom];
//        }
//    }
//    if (messages != NULL)
//        free_all_messages(messages, messages_used);
//}

- (void) addMessageToView:(struct message_store_info *) info time:(uint64_t)now {
    //NSAttributedString * boxedString = makeMessage (info, now, 0);
}

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
        [vc loadData];   // refresh the contacts list
        [tableView reloadData];
        [self addToBadgeNumber:1];
    } else {  // this contact is already displayed, update the contents
        [conversation displayContact: contact];
    }
}

static char * string_replace (char * original, char * pattern, char * repl)
{
    char * p = strstr (original, pattern);
    if (p == NULL) {
        printf ("error: string %s does not contain '%s'\n", original, pattern);
        /* this is a serious error -- need to figure out what is going on */
        exit (1);
    }
    size_t olen = strlen (original);
    size_t plen = strlen (pattern);
    size_t rlen = strlen (repl);
    size_t size = olen + 1 + rlen - plen;
    char * result = malloc_or_fail (size, "string_replace");
    size_t prelen = p - original;
    memcpy (result, original, prelen);
    memcpy (result + prelen, repl, rlen);
    char * postpos = p + plen;
    size_t postlen = olen - (postpos - original);
    memcpy (result + prelen + rlen, postpos, postlen);
    result [size - 1] = '\0';
    /*  printf ("replacing %s with %s in %s gives %s\n",
     pattern, repl, original, result); */
    return result;
}
static void update_time_read (const char * contact)
{
    keyset *k;
    int nkeys = all_keys(contact, &k);
    for (int ikey = 0; ikey < nkeys; ikey++) {
        char * path = contact_last_read_path(contact, k [ikey]);
        if (path != NULL) {
            NSLog(@"update_time_read path is %s\n", path);
            int fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR);
            write(fd, " ", 1);
            close (fd);   /* all we are doing is setting the modification time */
            free (path);
        }
    }
    free (k);
}

static char * contact_last_read_path (const char * contact, keyset k)
{
    char * directory = key_dir (k);
    if (directory != NULL) {
        directory = string_replace(directory, "contacts", "xchat");
        char * path = strcat3_malloc(directory, "/", "last_read", "contact_last_read_path");
        free (directory);
        return path;
    }
    return NULL;
}

static uint64_t last_time_read (const char * contact)
{
    keyset *k = NULL;
    uint64_t last_read = 0;
    int nkeys = all_keys(contact, &k);
    for (int ikey = 0; ikey < nkeys; ikey++) {
        char * path = contact_last_read_path(contact, k [ikey]);
        if (path != NULL) {
            // NSLog(@"new path for %s is %s\n", contact, path);
            struct stat st;
            if (stat(path, &st) == 0) {
                if (last_read < st.st_mtimespec.tv_sec)
                    last_read = st.st_mtimespec.tv_sec;
            } else {   // last_read file does not exist
                update_time_read(contact);
                last_read = time (NULL);
            }
            free (path);
        }
    }
    if (nkeys > 0)
        free (k);
    static uint64_t delta = 0;
    if (delta == 0)
        delta = time (NULL) - allnet_time();  // record the difference in epoch
    // NSLog(@"for %s last time is %lld/%lld, now %ld/%lld\n", contact, last_read, last_read - delta, time(NULL), allnet_time());
    return last_read - delta;
}
@end


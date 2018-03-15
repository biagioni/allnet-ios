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
#import "allnet_xchat-Swift.h"
#import "MessageModel.h"

#include <sys/stat.h>
#include <pthread.h>
#include "lib/packet.h"
#include "lib/util.h"
#include "xchat/store.h"
#include "xchat/message.h"
#include "lib/keys.h"
#include "xchat/xcommon.h"
#include "xchat/cutil.h"


@interface CHelper()
@property int sock;

@end

@implementation CHelper : NSObject

//clean
- (NSString *) getMessagesSize {
    int64_t sizeInBytes = conversation_size (self.xcontact);
    int64_t sizeInMegabytes = sizeInBytes / (1000 * 1000);
    char sizeBuf [100];
    if (sizeInMegabytes >= 10)
        snprintf (sizeBuf, sizeof (sizeBuf), "%" PRId64 "", sizeInMegabytes);
    else
        snprintf (sizeBuf, sizeof (sizeBuf), "%" PRId64 ".%02" PRId64 "", sizeInMegabytes, (sizeInBytes / 10000) % 100);
    NSString * actualSize = [[NSString alloc] initWithUTF8String:sizeBuf];
    return actualSize;
}

//clean
+ (NSString *) generateRandoKey {
#define MAX_RANDOM  15   // 14 characters plus a null character
    char randomString [MAX_RANDOM];
    random_string(randomString, MAX_RANDOM);
    normalize_secret(randomString);
    return [[NSString alloc] initWithUTF8String:randomString];
}

//clean
- (void) initialize: (int) sock : (NSString *) contact {
    self.sock = sock;
    self.xcontact = strcpy_malloc (contact.UTF8String, "ConversationUITextView initialize contact");
    update_time_read (contact.UTF8String);
}

//clean
- (NSMutableArray *)getMessages {
    update_time_read(self.xcontact);
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
            MessageModel *model = [[MessageModel alloc] init];
            model.message = [[NSString alloc] initWithUTF8String:mi.message];
            model.msg_type = mi.msg_type;
            model.dated = basicDate(mi.time, mi.tz_min);
            model.message_has_been_acked = mi.message_has_been_acked;
            model.rcvd_ackd_time = mi.rcvd_ackd_time;
            [converted_messages addObject:model];
        } @catch (NSException *e) {
            NSLog(@"message %s is not valid UTF8, ignoring\n", mi.message);
        }
        free ((void *)mi.message);
    }
    converted_messages = [[converted_messages reverseObjectEnumerator] allObjects];
    return converted_messages;
}

+ (NSString *) getKeyFor: (const char *) contact {
    NSString * randomSecret = nil;
    NSString * enteredSecret = nil;
    keyset * keys = NULL;
    int nk = all_keys (contact, &keys);
    for (int ki = 0; ki < nk; ki++) {
        char * s1 = NULL;
        char * s2 = NULL;
        char * content = NULL;
        incomplete_exchange_file(contact, keys [ki], &content, NULL);
        NSLog (@"incomplete content for %s %d (%d/%d) is '%s'\n", contact, keys [ki], ki, nk, content);
        if (content != NULL) {
            char * first = index (content, '\n');
            if (first != NULL) {
                *first = '\0';  // null terminate hops count
                s1 = first + 1;
                char * second = index (s1, '\n');
                if (second != NULL) {
                    *second = '\0';  // null terminate first secret
                    s2 = second + 1;
                    char * third = index (s2, '\n');
                    if (third != NULL) // null terminate second secret
                        *third = '\0';
                    if (*s2 == '\0')
                        s2 = NULL;
                    NSLog (@"first %s, second %s, third %s, s1 %s, s2 %s\n", first, second, third, s1, s2);
                }
                if (s1 != NULL)
                    randomSecret = [[NSString alloc] initWithUTF8String:s1];
                if (s2 != NULL)
                    enteredSecret = [[NSString alloc] initWithUTF8String:s2];
                free (content);
            }
        }
        if (keys != NULL)
            free (keys);
    }
    return randomSecret;
}

//clean
static NSString * basicDate (uint64_t time, int tzMin) {
    // objective C time begins on January 1st, 2001.  allnet time begins on January 1st, 2000.
    uint64_t unixTime = time + ALLNET_Y2K_SECONDS_IN_UNIX;
    NSDate * date = [[NSDate alloc] initWithTimeIntervalSince1970:unixTime];
    // date formatter code from https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html#//apple_ref/doc/uid/TP40002369-SW1
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    NSString * dateString = [dateFormatter stringFromDate:date];
//    if (local_time_offset() != tzMin) {
//        // some of this code from cutil.c
//        int delta = tzMin - local_time_offset();
//        while (delta < 0)
//            delta += 0x10000;  // 16-bit value
//        if (delta >= 0x8000)
//            delta = 0x10000 - delta;
//        NSString * offset = [[NSString alloc] initWithFormat:@" (%+d:%d)", delta / 60, delta % 60];
//        [dateString stringByAppendingString:offset];
//    }
//    dateString = [dateString stringByAppendingString:@"\n"];
    return dateString;
}

//clean
static int local_time_offset ()
{
    time_t now = time (NULL);
    
    struct tm now_ltime_tm;
    localtime_r (&now, &now_ltime_tm);
    struct tm gtime_tm;
    gmtime_r (&now, &gtime_tm);
    return (delta_minutes (&now_ltime_tm, &gtime_tm));
}

//clean
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

//clean
static void send_message_in_separate_thread (int sock, char * contact, char * message, size_t mlen)
{
    struct data_to_send * d = malloc_or_fail(sizeof (struct data_to_send), "send_message_with_delay");
    d->sock = sock;
    d->contact = strcpy_malloc (contact, "send_message_with_delay contact");
    d->message = memcpy_malloc(message, mlen, "send_message_with_delay message");
    d->mlen = mlen;
    pthread_t t;
    if (pthread_create(&t, NULL, send_message_thread, (void *) d) != 0)
        perror ("pthread_create for send_message_with_delay");
}

//clean
static void * send_message_thread (void * arg)
{
    struct data_to_send * d = (struct data_to_send *) arg;
    int sock = d->sock;
    char * contact = d->contact;
    char * message = d->message;
    int mlen = (int)(d->mlen);
    free (arg);
    uint64_t seq = 0;
    pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock (&lock);
    NSLog(@"sending message to %s, socket %d\n", contact, sock);
    while (1) {    // repeat until the message is sent
        seq = send_data_message(sock, contact, message, mlen);
        if (seq != 0)
            break;   // message sent
        NSLog (@"result of send_data_message is 0, socket is %d\n", sock);
    }
    NSLog(@"message sent, result %" PRIu64 ", socket %d\n", seq, sock);
    pthread_mutex_unlock (&lock);
    free (contact);
    free (message);
    return (void *) seq;
}

//clean
struct data_to_send {
    int sock;
    char * contact;
    char * message;
    size_t mlen;
};

//clean
- (MessageModel*)sendMessage:(NSString*) message {
    if ((message.length > 0) && (self.xcontact != NULL)) {  // don't send empty messages
        char * message_to_send = strcpy_malloc(message.UTF8String, "messageEntered/to_save");
        size_t length_to_send = strlen(message_to_send); // not textView.text.length
        send_message_in_separate_thread (self.sock, self.xcontact, message_to_send, length_to_send);
        MessageModel *model = [[MessageModel alloc] init];
        model.message = [[NSString alloc] initWithUTF8String:message_to_send];
        model.msg_type = MSG_TYPE_SENT;
        model.dated = basicDate(allnet_time(), local_time_offset());
        model.msize = length_to_send;
        return model;
    }
    return NULL;
}
#if 0
- (void)sendMessage:(NSString*) message {
    if ((message.length > 0) && (self.xcontact != NULL)) {  // don't send empty messages
        char * message_to_send = strcpy_malloc(message.UTF8String, "messageEntered/to_save");
        size_t length_to_send = strlen(message_to_send); // not textView.text.length
        send_message_in_separate_thread (self.sock, self.xcontact, message_to_send, length_to_send);
        struct message_store_info info;
        bzero (&info, sizeof (info));
        info.msg_type = MSG_TYPE_SENT;
        info.message = message_to_send;
        info.msize = length_to_send;
        info.time = allnet_time();
        info.tz_min = local_time_offset();
    }
}
#endif


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

//clean
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

- (uint64_t) last_time_read: (const char *) contact
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


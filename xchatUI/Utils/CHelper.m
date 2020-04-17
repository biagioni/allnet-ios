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
#include "lib/app_util.h"


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
+ (NSString *) generateRandomKey {
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

static char * contact_for_key (keyset k)
{
    char * result = "";
    char ** contacts = NULL;
    int nc = all_contacts(&contacts);
    for (int ic = 0; ic < nc; ic++) {
        keyset * keys = NULL;
        int nk = all_keys (contacts [ic], &keys);
        for (int ik = 0; ik < nk; ik++) {
            if ((keys [ik] == k) && (! is_group (contacts [ic]))) {
                printf ("key %d matches contact %s\n", k, contacts [ic]);
                result = strcpy_malloc(contacts [ic], "contact_for_key");
            }
        }
        if (keys != NULL)
            free (keys);
    }
    if (contacts != NULL)
        free (contacts);
    return result;
}

//clean
- (NSMutableArray *)getMessages {
    update_time_read(self.xcontact);
    return [self allMessages];
}

- (NSMutableArray *) allMessages{
    struct message_store_info * messages = NULL;
    int messages_used = 0;
    int messages_allocated = 0;
    list_all_messages (self.xcontact, &messages, &messages_allocated, &messages_used);
    NSMutableArray * converted_messages = [[NSMutableArray alloc] initWithCapacity:messages_used];
    if (messages_used > 0) {
        struct message_store_info * prev_mi = NULL;
        MessageModel * prevModel = nil;
        for (int i = 0; i < messages_used; i++) {
            int index = messages_used - i - 1;
            struct message_store_info mi = messages [index];
            NSString *contactName = [[NSString alloc] initWithUTF8String: contact_for_key(mi.keyset)];
            if ((prev_mi != NULL) && (prevModel != nil) &&
                (mi.msg_type == MSG_TYPE_SENT) && (prev_mi->msg_type == MSG_TYPE_SENT) &&
                (mi.time == prev_mi->time) && (strcmp (mi.message, prev_mi->message) == 0)) {
            // redundant group message, add info rather than message
                [prevModel.group_sent addObject:contactName];
                if (mi.message_has_been_acked)
                    [prevModel.group_acked addObject:contactName];
                prevModel.message_has_been_acked |= mi.message_has_been_acked;
                prevModel.contact_name = nil;
            } else {
printf ("message %s, prev %p/%p, contactName %s, index %d\n", mi.message, prev_mi, prevModel, contactName.UTF8String, index);
if ((prevModel != nil) && (prev_mi != NULL)) printf ("msg_type %d %d, time %d %d, strcmp %d\n", mi.msg_type, prev_mi->msg_type, (int)mi.time, (int)prev_mi->time, strcmp (mi.message, prev_mi->message));
                MessageModel *model = [[MessageModel alloc] init];
                @try {   // initWithUTF8String will fail if the string is not valid UTF8
                    model.message = [[NSString alloc] initWithUTF8String:mi.message];
                } @catch (NSException *e) {
                    NSLog(@"message %s is not valid UTF8, ignoring\n", mi.message);
                    model.message = @"(message is invalid UTF8, cannot be displayed)";
                }
                model.msg_type = mi.msg_type;
                model.dated = basicDate(mi.time, mi.tz_min);
                model.message_has_been_acked = mi.message_has_been_acked;
                model.sent_time = mi.time;
                model.rcvd_ackd_time = mi.rcvd_ackd_time;
                model.prev_missing = (int)mi.prev_missing;
                model.contact_name = (is_group(self.xcontact) ? contactName : nil);
                model.group_sent = [[NSMutableSet alloc] initWithObjects:contactName, nil];
                if (mi.message_has_been_acked) {
                    model.group_acked = [[NSMutableSet alloc] initWithObjects:contactName, nil];
                } else {
                    model.group_acked = [[NSMutableSet alloc] init];
                }
                [converted_messages addObject:model];
                prevModel = model;
            }
            prev_mi = messages + index;
        }
    }
    if (messages != NULL)
        free_all_messages(messages, messages_used);
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
    }
    if (keys != NULL)
        free (keys);
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
    // NSString * dateWithName = [dateString stringByAppendingString:@" foo"];
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
    seq = send_data_message(sock, contact, message, mlen);
    NSLog (@"result of send_data_message is 0, socket is %d\n", sock);
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
NSLog(@"sending message %@\n", message);
        char * message_to_send = strcpy_malloc(message.UTF8String, "messageEntered/to_save");
        size_t length_to_send = strlen(message_to_send); // not textView.text.length
        send_message_in_separate_thread (self.sock, self.xcontact, message_to_send, length_to_send);
        MessageModel *model = [[MessageModel alloc] init];
        model.message = message;
        model.msg_type = MSG_TYPE_SENT;
        model.dated = basicDate(allnet_time(), local_time_offset());
        model.msize = (int *)length_to_send;
        model.prev_missing = 0;
        model.contact_name = nil;
        model.group_sent = [[NSMutableSet alloc] init];
        model.group_acked = [[NSMutableSet alloc] init];
        return model;
    }
    return NULL;
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

+ (BOOL) exchange_is_complete: (const char *) contact
{
    char ** contacts = NULL;
    keyset * keys = NULL;
    int * status = NULL;
    int nk = incomplete_key_exchanges(&contacts, &keys, &status);
    if ((nk <= 0) || (contacts == NULL) || (keys == NULL) || (status == NULL))
        return false;
    BOOL result = true;
    for (int i = 0; i < nk; i++) {
        if ((strcmp (contacts [i], contact) == 0) &&
            ((status [i] & KEYS_INCOMPLETE_NO_CONTACT_PUBKEY) != 0))
            result = false;
    }
    return result;
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

+ (void) send_push_request: (NSData*) device_token
{
    const char * token = (char *) [device_token bytes];
    const char public_key [] =
    "-----BEGIN RSA PUBLIC KEY-----\n"
    "MIICCgKCAgEA22TQgMWDQ8HqpEh96L+eb9UpvY26bqtTZAR+9zTIM5bC880Bn/t1\n"
    "81znkrJjVyors3POm5JKrBHfnC5WNIF+YUXqwxzQsAPD5k6/6R5G9mfcW7jFKpbr\n"
    "FGH/V59HPUwCzDg0S2PTZBIlv4vhcT1uBh+KBATEd1j+HCPSLm/FosGRW2MyG1Zh\n"
    "sGmKcboNXwhQf9Fzd8SeISIbdG4ZBXhSuWaxM0YT9U8W/V/ZKuh/opDHNC0rKK5p\n"
    "K69RafPXB6iLVd3eFzV6GAj3LbPR6HRmI2qmxiTYVrNkYQeMc8+SNmLPMrETvpFU\n"
    "nkEgECwck0Ij37mvXAI75F83ZZGVrurYjmeqzTlzRy5xsYSCSR0WzOjvUC4UmRX6\n"
    "e0rUJBMJ22Mv+xLMFO2WAYwVMDCxsD0L49TcwoLOfglYTuLz+Z9nM60WGluWHBxG\n"
    "ldRzQOssEYeOpXflFx4SChwkhZ7BZuDHqp8xj5lIqwOggQHVTjbo4uXO641fmfpP\n"
    "1xYKTIrHK4cjU5H4fEA4jxjl3B04w6nO2O5l2MTTRcKhSklc0ghWCLFsnZaHNJzE\n"
    "8/LNRA31BTjPDbsW7K3ZhIpfQ1d2seWe/5LoN/HHWKubtPxUpCqZLPSsiVb2NrID\n"
    "pbTwtDNiNsjkyY+Vox3f+tWiocIop3MZsSiGceqTxlY1NgN9lZl/AyECAwEAAQ==\n"
    "-----END RSA PUBLIC KEY-----\n";
    allnet_rsa_pubkey rsa;
    NSString * fname = [NSTemporaryDirectory() stringByAppendingString:@"allnet-push-pubkey.txt"];
    write_file (fname.UTF8String, public_key, sizeof (public_key), 1);
    if (allnet_rsa_read_pubkey (fname.UTF8String, &rsa) == 0) {
        printf ("failed to read pubkey\n");
        return;
    }
    char buf [ALLNET_MTU];
    struct allnet_header * hp = (struct allnet_header *) buf;
    char * data = buf + sizeof (struct allnet_header);
    char timestamp [ALLNET_TIME_SIZE];
    writeb64(timestamp, allnet_time());
    memset(hp, 0, sizeof (struct allnet_header));  // default everything to zero
    hp->version = ALLNET_VERSION;
    hp->message_type = ALLNET_TYPE_DATA;
    hp->max_hops = 5;
    hp->transport = ALLNET_TRANSPORT_DO_NOT_CACHE;
    // char since [] = { 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47 };
    // NSLog(@"temporary directory is %@\n", NSTemporaryDirectory());
    int r = create_push_request (rsa, ALLNET_PUSH_APNS_ID,
                                 token, (int)[device_token length], timestamp, NULL, data,
                                 sizeof (buf) - sizeof (struct allnet_header));
    // send an encrypted request for everything to the push server
    local_send (buf, r + sizeof (struct allnet_header), 99);
}
@end


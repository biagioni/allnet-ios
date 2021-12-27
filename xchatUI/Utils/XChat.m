//
//  XChatSocket.m
//  xchat UI
//
//  Created by e on 2015/05/22.
//  Copyright (c) 2015 allnet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
@import CoreFoundation;

#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <netinet/tcp.h>
#include <dirent.h>

#import "XChat.h"
#import "allnet_xchat-Swift.h"

#include "xchat/xcommon.h"
#include "limits.h"
#include "lib/util.h"
#include "xchat/cutil.h"
#include "lib/app_util.h"
#include "lib/allnet_log.h"
#include "lib/trace_util.h"
#include "lib/configfiles.h"
#include "lib/priority.h"

@interface XChat ()

@property int sock;
///TODO convert to delegate in the 
@property MessageViewModel * conversation;
@property ContactViewModel * contacts;
@property MoreViewModel * more;
@property KeyViewModel * key;
@property CFRunLoopSourceRef runLoopSource;
@property CFSocketRef iOSSock;
@property CFRunLoopRef initialRunLoop;

@end

@implementation XChat

// globals
static pthread_mutex_t key_generated_mutex;
static int user_messages_received = 0;

// variables for tracing
static int trace_count = 0;
static unsigned long long int trace_start_time = 0;
static char expecting_trace [MESSAGE_ID_SIZE];

// hack to make self object available to C code -- should only be one Xchat object anyway
static XChat * mySelf = NULL;

- (void)initialize {
  self.initialRunLoop = CFRunLoopGetCurrent();
  mySelf = self;
  pthread_mutex_init(&key_generated_mutex, NULL);
}

- (void)disconnect {
  NSLog (@"Xchat disconnect socket %d\n", self.sock);
  CFRunLoopRemoveSource(self.initialRunLoop, self.runLoopSource, kCFRunLoopCommonModes);
  NSLog(@"after removing, run loop %p %s source\n", self.initialRunLoop,
        (CFRunLoopContainsSource(self.initialRunLoop, self.runLoopSource, kCFRunLoopCommonModes) ?
         "contains" : "does not contain"));
  // NSLog(@"CFRunLoopRemoveSource(%@, %@)\n", currentRunLoop, self.runLoop);
  xchat_end (self.sock);   // close the socket, and do any other cleanup needed
  CFSocketInvalidate(self.iOSSock);
  close (self.sock);
}

- (BOOL)connect {
  return [self initSocket:@"reconnect"];
}

- (BOOL)initSocket: (NSString *)debugInfo {
  self.sock = xchat_init ("xchat", NULL);
  if (self.sock < 0)
    return false;
  NSLog(@"Xchat.m %@ result of calling xchat_init is %d\n", debugInfo, self.sock);
  self.iOSSock = CFSocketCreateWithNative(NULL, self.sock, kCFSocketDataCallBack,
                                                 (CFSocketCallBack)&dataAvailable, NULL);
  // if you ever need to bind, use CFSocketSetAddress -- but not needed here
  self.runLoopSource = CFSocketCreateRunLoopSource(NULL, self.iOSSock, 100);
  CFRunLoopAddSource(self.initialRunLoop, self.runLoopSource, kCFRunLoopCommonModes);
  return true;
}

- (int)getSocket {
  return self.sock;
}

+ (int)userMessagesReceived {
  return user_messages_received;
}

struct send_key_arg {
  int sock;
  char * contact;
  char * secret1;
  char * secret2;
  int hops;
};

// invoked with lock held, releases the lock
static void * send_key (void * arg_void) {
  // now save the result
  struct send_key_arg * arg = (struct send_key_arg *) arg_void;
  // next line will be slow if it has to generate the key from scratch
  create_contact_send_key(arg->sock, arg->contact, arg->secret1, arg->secret2, arg->hops);
  make_invisible(arg->contact);  // make sure the new contact is not (yet) visible
  pthread_mutex_unlock(&key_generated_mutex);
  [mySelf.key notificationOfGeneratedKeyForContact:[[NSString alloc] initWithUTF8String:arg->contact]];
  free(arg->contact);
  if (arg->secret1 != NULL)
    free (arg->secret1);
  if (arg->secret2 != NULL)
    free (arg->secret2);
  // NSLog(@"unlocked key generated mutex 2\n");
  printf ("finished generating and sending key\n");
  free (arg_void);  // we must free it
  return NULL;
}

- (void) requestNewContact:(NSString *)contact maxHops: (NSUInteger) hops
                   secret1:(NSString *) s1 optionalSecret2:(NSString *) s2 {
  pthread_mutex_lock(&key_generated_mutex);
  struct send_key_arg * arg =
  (struct send_key_arg *)malloc_or_fail(sizeof (struct send_key_arg), "send_key thread");
  arg->sock = self.sock;
  arg->contact = strcpy_malloc (contact.UTF8String, "requestNewContact contact");
  arg->secret1 = NULL;
  arg->secret2 = NULL;
  if ((s1 != nil) && (s1 != NULL) && (s1.length > 0)) {
    arg->secret1 = strcpy_malloc (s1.UTF8String, "requestNewContact secret");
    normalize_secret(arg->secret1);
  }
  if ((s2 != nil) && (s2 != NULL) && (s2.length > 0)) {
    arg->secret2 = strcpy_malloc (s2.UTF8String, "requestNewContact secret2");
    normalize_secret(arg->secret2);
  }
  arg->hops = (int)hops;
  //create_contact_send_key(self.sock, contact, s1, s2, (int)hops);
  pthread_t thread;
  pthread_create(&thread, NULL, send_key, (void *) arg);
}

- (void)requestBroadcastKey:(NSString *)contact maxHops: (NSUInteger) hops {
  subscribe_broadcast(self.sock, (char *) (contact.UTF8String));
}

static void dataAvailable (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address,
                           const void * dataVoid, void * info) {
  if (dataVoid == NULL)
    return;
  CFDataRef data = (CFDataRef) ((char *)dataVoid);
  long signed_size = CFDataGetLength(data);
  if ((signed_size <= 0) || (signed_size >= UINT_MAX))
    return;
  unsigned int psize = (unsigned int)signed_size;
  char * dataChar = (char *)(CFDataGetBytePtr(data));
  int sock = CFSocketGetNative(s);
  unsigned int priority = ALLNET_PRIORITY_EPSILON;
  if (psize > 4) {
    psize -= 4;
    priority = (unsigned int) readb32 (dataChar + psize);
  }
  receivePacket(sock, dataChar, psize, priority);
}

// main function to call handle_packet and process the results
static void receivePacket (int sock, const char * data, unsigned int dlen, unsigned int priority)
{
  if (dlen < ALLNET_HEADER_SIZE)
    return;
  local_send_keepalive(0);
  const struct allnet_header * hp = (struct allnet_header *) data;
  if (hp->message_type == ALLNET_TYPE_KEY_REQ) { // special handling for key requests
    extern void keyd_handle_packet (const char * message, int msize); // from keyd.c
    keyd_handle_packet (data, dlen);
    return;
  }   // else: any other kind of packet
  static int last_length = 0;
  if (dlen != last_length) {
    last_length = dlen;
  }
  // NSLog (@"received %d-byte packet, type %d\n", dlen, data [1] & 0xff);
  int verified, duplicate, broadcast;
  uint64_t seq;
  uint64_t missing;
  char * peer;
  keyset kset;
  char * desc;
  char * message;
  struct allnet_ack_info acks;
  acks.num_acks = 0;
  struct allnet_mgmt_trace_reply * trace = NULL;
  time_t mtime = 0;
  int mlen = handle_packet(sock, (char *)data, dlen, priority, &peer, &kset, &message, &desc,
                           &verified, &seq, &mtime, &missing, &duplicate, &broadcast, &acks, &trace);
  if ((mlen > 0) && verified) {  // received a packet
    NSLog(@"mlen %d, verified %d, duplicate %d, broadcast %d, peer %s\n",
          mlen, verified, duplicate, broadcast, peer);
    NSString * contact = [[NSString alloc] initWithUTF8String:peer];
    if (! duplicate) {
      user_messages_received++;
      NSString * msg = [[NSString alloc] initWithUTF8String:message];
      if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        [mySelf.conversation receivedNewMessageForContact:contact message:msg];
      } else {
        AppDelegate * appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
        [appDelegate notifyMessageReceivedWithContact:contact message:msg];
      }
    }
    // NSLog(@"XChat.m: refreshed the conversation UI text view and the contacts UI table view\n");
  } else if (mlen == -1) {        // successfully exchanged keys
    NSLog(@"key exchange successfully completed for peer %s\n", peer);
    NSString * contact = [[NSString alloc] initWithUTF8String:peer];
    [mySelf.key notificationkeyExchangeCompletedForContact:contact];
  } else if (mlen == -2) {  // confirm successful subscription
      NSLog(@"got subscription %s\n", peer);
  } else if ((mlen == -4) && (trace != NULL) &&
             (memcmp (trace->trace_id, expecting_trace, MESSAGE_ID_SIZE) == 0)) {  // got trace result
    // NSLog(@"got trace result with %d entries\n", trace->num_entries);
    char string [10000];
    trace_to_string(string, sizeof (string), trace, trace_count, trace_start_time);
    NSString * msg = [[NSString alloc] initWithUTF8String:string];
    [mySelf.more receiveTraceWithMessage:msg];
  }
  for (int i = 0; i < acks.num_acks; i++) {
    printf ("displaying ack sequence number %lld for peer %s\n", acks.acks[i], acks.peers[i]);
    NSString * nsContact = [[NSString alloc] initWithUTF8String:acks.peers[i]];
    [mySelf.conversation ackMessageForContact:nsContact];
  }
}

// call receivePacket in the main thread
void receiveAdPacket (const char * data, unsigned int dlen, unsigned int priority)
{
  if ((dlen > ALLNET_MTU) || (dlen <= 0))
    return;
  char * bufferedData = memcpy_malloc(data, dlen, "receiveAdPacket");
  dispatch_async(dispatch_get_main_queue(), ^{
    receivePacket(-1, bufferedData, dlen, priority);
    free(bufferedData);
  });
}


- (void) setMessageVM:(NSObject *)object {
  mySelf.conversation = (MessageViewModel*)object;
}

- (void) setMoreVM:(NSObject *)object {
  mySelf.more = (MoreViewModel*)object;
}

- (void) setContactVM:(NSObject *)object{
  mySelf.contacts = (ContactViewModel*)object;
}

- (void) setKeyVM:(NSObject *)object{
  mySelf.key = (KeyViewModel*)object;
}


- (void) removeNewContact: (NSString *) contact {
  const char * sContact = (char *)contact.UTF8String;
  delete_contact (sContact);
}

- (void) resendKeyForNewContact: (NSString *) contact {
  NSLog(@"resending key to %@\n", contact);
  resend_contact_key (self.sock, contact.UTF8String);
  NSLog(@"resent key to %@\n", contact);
}

- (void) completeExchange: (NSString *) contact {
  NSLog(@"XChat.m key exchange completed, deleting exchange file\n");
  const char * sContact = (char *)contact.UTF8String;
  keyset * keys = NULL;
  int nk = all_keys (sContact, &keys);
  for (int ik = 0; ik < nk; ik++)   // delete the exchange file, if any
    incomplete_exchange_file(sContact, keys [ik], NULL, NULL);
  make_visible(sContact);
}

- (void) unhideContact:(NSString *)contact {
  make_visible(contact.UTF8String);
}

// returns the contents of the exchange file, if any: hops\nsecret1\n[secret2\n]
- (NSString *) incompleteExchangeData: (NSString *) contact {
  const char * sContact = (char *)contact.UTF8String;
  keyset * keys = NULL;
  int nk = all_keys (sContact, &keys);
  for (int ik = 0; ik < nk; ik++) {  // delete the exchange file, if any
    char * contents = NULL;
    incomplete_exchange_file(sContact, keys [ik], &contents, NULL);
    if (contents != NULL) {
      NSString * result = [[NSString alloc] initWithUTF8String:contents];
      free (contents);
      return result;
    }
  }
  return nil;
}

- (void) startTrace: (BOOL) wide_enough maxHops: (NSUInteger) hops showDetails: (BOOL) show_details {

  unsigned char addr [MESSAGE_ID_SIZE];
  memset (addr, 0, MESSAGE_ID_SIZE);
  trace_count++;
  trace_start_time = allnet_time_ms();
  int details = (show_details ? 1 : 0);
  if (! start_trace(self.sock, addr , 0, (int)hops, details, expecting_trace, 0)) {
    NSLog(@"unable to start trace\n");
  }
}

@end

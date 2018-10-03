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

@interface XChat ()

@property int sock;
///TODO convert to delegate in the 
@property MessageViewModel * conversation;
@property ContactViewModel * contacts;
@property MoreViewModel * more;
@property KeyViewModel * key;
@property CFRunLoopSourceRef runLoop;

@end

@implementation XChat

// globals
static pthread_mutex_t key_generated_mutex;
static int waiting_for_key = 0;
static char * keyContact = NULL;

// variables for tracing
static int trace_count = 0;
static unsigned long long int trace_start_time = 0;
static char expecting_trace [MESSAGE_ID_SIZE];

// hack to make self object available to C code -- should only be one Xchat object anyway
static XChat * mySelf = NULL;

- (void) initialize {
  // NSLog(@"calling xchat_init\n");
  self.sock = xchat_init ("xchat", NULL);
  NSLog(@"Xchat.m result of calling xchat_init is %d\n", self.sock);
  CFSocketRef iOSSock = CFSocketCreateWithNative(NULL, self.sock, kCFSocketDataCallBack,
                                                 (CFSocketCallBack)&dataAvailable, NULL);
  self.runLoop = CFSocketCreateRunLoopSource(NULL, iOSSock, 100);
  CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
  CFRunLoopAddSource(currentRunLoop, self.runLoop, kCFRunLoopCommonModes);
  mySelf = self;
  pthread_mutex_init(&key_generated_mutex, NULL);
  waiting_for_key = 0;
}

- (void)disconnect {
  NSLog (@"Xchat disconnect socket %d\n", self.sock);
  xchat_end (self.sock);   // close the socket, and do any other cleanup needed
  CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
  CFRunLoopRemoveSource(currentRunLoop, self.runLoop, kCFRunLoopCommonModes);
}

- (void)reconnect {
  self.sock = xchat_init ("xchat reconnect", NULL);
  NSLog(@"Xchat.m reconnect result of calling xchat_init is %d\n", self.sock);
  if (self.sock >= 0) {
    CFSocketRef iOSSock = CFSocketCreateWithNative(NULL, self.sock, kCFSocketDataCallBack,
                                                   (CFSocketCallBack)&dataAvailable, NULL);
    // if you ever need to bind, use CFSocketSetAddress -- but not needed here
    self.runLoop = CFSocketCreateRunLoopSource(NULL, iOSSock, 100);
    CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(currentRunLoop, self.runLoop, kCFRunLoopCommonModes);
  } else {
    char * crash = NULL;
    printf ("crashing %d\n", *crash);
  }
  NSLog (@"Xchat reconnect set socket to %d\n", self.sock);
}

- (int)getSocket {
  return self.sock;
}

struct request_key_arg {
  int sock;
  char * contact;
  char * secret1;
  char * secret2;
  int hops;
};
// invoked with lock held, releases the lock
static void * request_key (void * arg_void) {
  // now save the result
  struct request_key_arg * arg = (struct request_key_arg *) arg_void;
  waiting_for_key = 1;
  // next line will be slow if it has to generate the key from scratch
  create_contact_send_key(arg->sock, arg->contact, arg->secret1, arg->secret2, arg->hops);
  make_invisible(arg->contact);  // make sure the new contact is not (yet) visible
  waiting_for_key = 0;
  pthread_mutex_unlock(&key_generated_mutex);
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
  struct request_key_arg * arg =
  (struct request_key_arg *)malloc_or_fail(sizeof (struct request_key_arg), "request_key thread");
  arg->sock = self.sock;
  keyContact = strcpy_malloc (contact.UTF8String, "requestNewContact contact");
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
  //create_contact_send_key(self.sock, keyContact, keySecret, keySecret2, (int)hops);
  pthread_t thread;
  pthread_create(&thread, NULL, request_key, (void *) arg);
}

- (void)requestKey:(NSString *)contact maxHops: (NSUInteger) hops {
  subscribe_broadcast(self.sock, (char *) (contact.UTF8String));
}

static void dataAvailable (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address,
                           const void * dataVoid, void * info) {
  // static pthread_mutex_t packet_mutex = PTHREAD_MUTEX_INITIALIZER;
  if (dataVoid == NULL)
    return;
  CFDataRef data = (CFDataRef) ((char *)dataVoid);
  long signed_size = CFDataGetLength(data);
  if ((signed_size <= 0) || (signed_size >= UINT_MAX))
    return;
  unsigned int psize = (unsigned int)signed_size;
  char * dataChar = (char *)(CFDataGetBytePtr(data));
  // pthread_mutex_lock (&packet_mutex);
  int sock = CFSocketGetNative(s);
  // splitPacket(sock, dataChar, psize);  /* does all the packet processing */
  // pthread_mutex_unlock (&packet_mutex);
  int priority = ALLNET_PRIORITY_EPSILON;
  if (psize > 2) {
    psize -= 2;
    priority = readb16 (dataChar + psize);
  }
  if (psize < ALLNET_HEADER_SIZE)
    return;
  local_send_keepalive(1);
  struct allnet_header * hp = (struct allnet_header *) dataChar;
  if (hp->message_type == ALLNET_TYPE_KEY_REQ) { // special handling for key requests
    extern void keyd_handle_packet (const char * message, int msize); // from keyd.c
    keyd_handle_packet (dataChar, psize);
  } else {   // any other kind of packet
    receivePacket(sock, dataChar, psize, ALLNET_PRIORITY_EPSILON);
  }
}

// main function to call handle_packet and process the results
static void receivePacket (int sock, char * data, unsigned int dlen, unsigned int priority)
{
  static int last_length = 0;
  if (dlen != last_length) {
    last_length = dlen;
  }
  int verified, duplicate, broadcast;
  uint64_t seq;
  char * peer;
  keyset kset;
  char * desc;
  char * message;
  struct allnet_ack_info acks;
  acks.num_acks = 0;
  struct allnet_mgmt_trace_reply * trace = NULL;
  time_t mtime = 0;
  pthread_mutex_lock(&key_generated_mutex);  // don't allow changes to keyContact until a key has been generated
  if ((! waiting_for_key) && (mySelf.key != nil)  && (keyContact != nil)) {
    waiting_for_key = !waiting_for_key;
    [mySelf.key notificationOfGeneratedKeyForContact:[[NSString alloc] initWithUTF8String:keyContact]];
  }
  int mlen = handle_packet(sock, (char *)data, dlen, priority, &peer, &kset, &message, &desc,
                           &verified, &seq, &mtime, &duplicate, &broadcast, &acks, &trace);
  pthread_mutex_unlock(&key_generated_mutex);
  if ((mlen > 0) && verified) {  // received a packet
    NSLog(@"mlen %d, verified %d, duplicate %d, broadcast %d, peer %s\n",
          mlen, verified, duplicate, broadcast, peer);
    NSString * contact = [[NSString alloc] initWithUTF8String:peer];
    if (! duplicate) {
      NSString * msg = [[NSString alloc] initWithUTF8String:message];
      if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        [mySelf.conversation receivedNewMessageForContact:contact message:msg];
      }else{
        AppDelegate * appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
        [appDelegate notifyMessageReceivedWithContact:contact message:msg];
      }
    }
    // NSLog(@"XChat.m: refreshed the conversation UI text view and the contacts UI table view\n");
  } else if (mlen == -1) {        // successfully exchanged keys
    waiting_for_key = !waiting_for_key;
    NSLog(@"key exchange successfully completed for peer %s\n", keyContact);
    NSString * contact = [[NSString alloc] initWithUTF8String:keyContact];
    [mySelf.key notificationkeyExchangeCompletedForContact:contact];
    pthread_mutex_lock(&key_generated_mutex);  // changing globals, forbid access for others that may also change them
    pthread_mutex_unlock(&key_generated_mutex);
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
  if (! waiting_for_key) {
    NSLog(@"resending key to %@\n", contact);
    resend_contact_key (self.sock, contact.UTF8String);
    NSLog(@"resent key to %@\n", contact);
  } else {
    NSLog(@"resend key for new contact %@: still generating key\n", contact);
  }
}

- (void) completeExchange: (NSString *) contact {
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

- (void) startTrace: (BOOL) wide_enough maxHops: (NSUInteger) hops showDetails: (BOOL) details {

  unsigned char addr [MESSAGE_ID_SIZE];
  memset (addr, 0, MESSAGE_ID_SIZE);
  trace_count++;
  trace_start_time = allnet_time_ms();
  if (! start_trace(self.sock, addr , 0, (int)hops, 0, expecting_trace, 0)) {
    NSLog(@"unable to start trace\n");
  }
}

@end

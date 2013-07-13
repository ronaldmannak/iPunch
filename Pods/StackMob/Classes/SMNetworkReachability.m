/*
 * Copyright 2012-2013 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "SMNetworkReachability.h"
#import "SMIncrementalStore.h"

#define DLog(fmt, ...) NSLog((@"Performing %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

NSString * SMNetworkStatusDidChangeNotification = @"SMNetworkStatusDidChangeNotification";
NSString * SMCurrentNetworkStatusKey = @"SMCurrentNetworkStatusKey";

typedef void (^SMNetworkStatusBlock)(SMNetworkStatus status);
typedef SMCachePolicy (^SMCachePolicyReturnBlock)(SMNetworkStatus status);

@interface SMNetworkReachability ()

@property (nonatomic) int networkStatus;
@property (readwrite, nonatomic, copy) SMNetworkStatusBlock localNetworkStatusBlock;
@property (readwrite, nonatomic, copy) SMCachePolicyReturnBlock localNetworkStatusBlockWithReturn;

- (void)addNetworkStatusDidChangeObserver;
- (void)removeNetworkStatusDidChangeObserver;
- (void)networkChangeNotificationFromAFNetworking:(NSNotification *)notification;

@end

@implementation SMNetworkReachability

@synthesize networkStatus = _networkStatus;

- (id)init
{
    self = [super initWithBaseURL:[NSURL URLWithString:@"http://api.stackmob.com"]];
    
    if (self) {
        self.networkStatus = -1;
        self.localNetworkStatusBlock = nil;
        [self addNetworkStatusDidChangeObserver];
    }
    
    return self;
}

- (SMNetworkStatus)currentNetworkStatus
{
    return self.networkStatus;
}

- (void)addNetworkStatusDidChangeObserver
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChangeNotificationFromAFNetworking:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
}

- (void)removeNetworkStatusDidChangeObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];
}

- (void)setNetworkStatusChangeBlock:(void (^)(SMNetworkStatus))block
{
    self.localNetworkStatusBlock = block;
}

- (void)setNetworkStatusChangeBlockWithCachePolicyReturn:(SMCachePolicy (^)(SMNetworkStatus))block
{
    self.localNetworkStatusBlockWithReturn = block;
}

- (void)networkChangeNotificationFromAFNetworking:(NSNotification *)notification
{
    int notificationNetworkStatus = [self translateAFNetworkingStatus:[[[notification userInfo] objectForKey:AFNetworkingReachabilityNotificationStatusItem] intValue]];
    
    if (self.networkStatus != notificationNetworkStatus) {
        self.networkStatus = notificationNetworkStatus;
        if (SM_CORE_DATA_DEBUG) {DLog(@"STACKMOB SYSTEM UPDATE: Network reachability has changed to %d", notificationNetworkStatus)};
        if (self.localNetworkStatusBlock) {
            self.localNetworkStatusBlock(self.networkStatus);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SMNetworkStatusDidChangeNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:self.currentNetworkStatus], SMCurrentNetworkStatusKey, nil]];
        if (self.localNetworkStatusBlockWithReturn) {
            SMCachePolicy newCachePolicy = self.localNetworkStatusBlockWithReturn(self.networkStatus);
            [[NSNotificationCenter defaultCenter] postNotificationName:SMSetCachePolicyNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:newCachePolicy], @"NewCachePolicy", nil]];
        }
    }
    
}

- (SMNetworkStatus)translateAFNetworkingStatus:(AFNetworkReachabilityStatus)status
{
    switch (status) {
        case AFNetworkReachabilityStatusReachableViaWiFi:
            return SMNetworkStatusReachable;
            break;
        case AFNetworkReachabilityStatusNotReachable:
            return SMNetworkStatusNotReachable;
            break;
        case AFNetworkReachabilityStatusUnknown:
            return SMNetworkStatusUnknown;
            break;
        case AFNetworkReachabilityStatusReachableViaWWAN:
            return SMNetworkStatusReachable;
            break;
        default:
            return SMNetworkStatusUnknown;
            break;
    }
}

- (void)dealloc
{
    [self removeNetworkStatusDidChangeObserver];
}

@end

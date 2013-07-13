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

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "SMPushClient.h"
#import "SMPushToken.h"
#import "SMOAuth1Client.h"
#import "AFJSONRequestOperation.h"
#import "SMJSONRequestOperation.h"
#import "SMVersion.h"
#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/sysctl.h>

static SMPushClient *defaultClient = nil;

@interface SMPushClient ()

@property(nonatomic, readwrite, copy) NSString *appAPIVersion;
@property(nonatomic, readwrite, copy) NSString *publicKey;
@property(nonatomic, readwrite, copy) NSString *privateKey;
@property(nonatomic, readwrite, copy) NSString *host;
@property(nonatomic, retain) SMOAuth1Client *oauthClient;

@end

@implementation SMPushClient

@synthesize appAPIVersion = _SM_appAPIVersion;
@synthesize privateKey = _SM_privateKey;
@synthesize publicKey = _SM_publicKey;
@synthesize host = _SM_host;
@synthesize oauthClient = _SM_oauthClient;

- (id)initWithAPIVersion:(NSString *)appAPIVersion publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey
{
    return [self initWithAPIVersion:appAPIVersion publicKey:publicKey privateKey:privateKey pushHost:DEFAULT_PUSH_HOST];
}

- (id)initWithAPIVersion:(NSString *)appAPIVersion publicKey:(NSString *)publicKey privateKey:(NSString *)privateKey pushHost:(NSString *)pushHost;
{
    self = [self init];
    if (self)
    {
        self.appAPIVersion = appAPIVersion;
        self.publicKey = publicKey;
        self.privateKey = privateKey;
        self.host = pushHost;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", pushHost]];
        self.oauthClient = [[SMOAuth1Client alloc] initWithBaseURL:url consumerKey:publicKey secret:privateKey];
        NSString *acceptHeader = [NSString stringWithFormat:@"application/vnd.stackmob+json; version=%@", appAPIVersion];
        [self.oauthClient setDefaultHeader:@"Accept" value:acceptHeader];
        
#if TARGET_OS_MAC
        /* Get this for mac */
        NSString *deviceModel;
        NSString *systemVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
        
        size_t len = 0;
        sysctlbyname("hw.model", NULL, &len, NULL, 0);
        if(len)
        {
            char *model = malloc(len*sizeof(char));
            sysctlbyname("hw.model", model, &len, NULL, 0);
            
            deviceModel = [[NSString alloc] initWithCString:model encoding:NSUTF8StringEncoding];
            
            free(model);
        }
#else
        NSString *deviceModel   = [[UIDevice currentDevice] model];
        NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
#endif
        
        [self.oauthClient setDefaultHeader:@"User-Agent" value:[NSString stringWithFormat:@"StackMob/%@ (%@/%@; %@;)", SDK_VERSION, deviceModel, systemVersion, [[NSLocale currentLocale] localeIdentifier]]];
        [self.oauthClient setParameterEncoding:AFJSONParameterEncoding];
        if ([SMPushClient defaultClient] == nil)
        {
            [SMPushClient setDefaultClient:self];
        }
    }
    return self;
}

- (NSString *) tokenStringFromToken:(id)token
{
    return [token isMemberOfClass:[SMPushToken class]] ? ((SMPushToken *)token).tokenString : token;
}

- (NSString *) tokenTypeFromToken:(id)token
{
        return [token isMemberOfClass:[SMPushToken class]] ? ((SMPushToken *)token).type : TOKEN_TYPE_IOS;
}

- (void)registerDeviceToken:(id)token withUser:(NSString *)username onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self registerDeviceToken:token withUser:username overwrite:YES onSuccess:successBlock onFailure:failureBlock];
}

- (void)registerDeviceToken:(id)token withUser:(NSString *)username overwrite:(BOOL)overwrite onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSString *tokenString = [self tokenStringFromToken:token];
    NSString *type = [self tokenTypeFromToken:token];
    NSDictionary *tokenDict = [NSDictionary dictionaryWithObjectsAndKeys:tokenString, @"token",
                               type, @"type",
                               nil];
    
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:username, @"userId",
                          tokenDict, @"token",
                          [NSNumber numberWithBool:overwrite], @"overwrite",
                          nil];
    NSURLRequest *request = [self.oauthClient requestWithMethod:@"POST" path:@"register_device_token_universal" parameters:args];
  
    [self enqueueRequest:request onSuccess:^(NSDictionary *results) {successBlock();} onFailure:failureBlock];
}

- (void)broadcastMessage:(NSDictionary *)message onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSDictionary *args = [NSDictionary dictionaryWithObject:message forKey:@"kvPairs"];
    NSURLRequest *request = [self.oauthClient requestWithMethod:@"POST" path:@"push_broadcast_universal" parameters:args];
    [self enqueueRequest:request onSuccess:^(NSDictionary *results) {successBlock();} onFailure:failureBlock];
}

- (void)sendMessage:(NSDictionary *)message toUsers:(NSArray *)users onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"kvPairs", users, @"userIds", nil]; 
    NSURLRequest *request = [self.oauthClient requestWithMethod:@"POST" path:@"push_users_universal" parameters:args];
    [self enqueueRequest:request onSuccess:^(NSDictionary *results) {successBlock();} onFailure:failureBlock];
}

- (void)sendMessage:(NSDictionary *)message toTokens:(NSArray *)tokens onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSDictionary *payload = [NSDictionary dictionaryWithObject:message forKey:@"kvPairs"];
    NSMutableArray * tokensArray = [NSMutableArray array];
    [tokens enumerateObjectsUsingBlock:^(id token, NSUInteger idx, BOOL *stop) {
        NSString *tokenString = [self tokenStringFromToken:token];
        NSString *type = [self tokenTypeFromToken:token];
        NSDictionary * tokenDict = [NSDictionary dictionaryWithObjectsAndKeys:tokenString, @"token", type, @"type", nil];
        [tokensArray addObject:tokenDict];
    }];
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:tokensArray, @"tokens", payload, @"payload", nil];
    NSURLRequest *request = [self.oauthClient requestWithMethod:@"POST" path:@"push_tokens_universal" parameters:args];
    [self enqueueRequest:request onSuccess:^(NSDictionary *results) {successBlock();} onFailure:failureBlock];
}

- (void)getTokensForUsers:(NSArray *)users onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSString *usersString = [users componentsJoinedByString:@","];
    NSDictionary *args = [NSDictionary dictionaryWithObject:usersString forKey:@"userIds"];
    NSURLRequest *request = [self.oauthClient requestWithMethod:@"GET" path:@"get_tokens_for_users_universal" parameters:args];
    [self enqueueRequest:request onSuccess:^(NSDictionary *results) {
        NSDictionary *tokens = [results valueForKey:@"tokens"];
        NSMutableDictionary *resultDictionary = [[NSDictionary dictionary] mutableCopy];
        [tokens enumerateKeysAndObjectsUsingBlock:^(id user, id list, BOOL *stopEnum) {
            NSArray *tokenList = list;
            NSMutableArray *resultList = [[NSArray array] mutableCopy];
            [tokenList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSDictionary *token = obj;
                SMPushToken *result = [[SMPushToken alloc] initWithString:[token valueForKey:@"token"] type:[token valueForKey:@"type"]];
                int registeredTimeMillis = [[token valueForKey:@"registered_milliseconds"] intValue];
                if(registeredTimeMillis != 0) {
                    result.registrationTime = [NSDate dateWithTimeIntervalSince1970:registeredTimeMillis/1000];
                }
                [resultList addObject:result];
            }];
            [resultDictionary setValue:resultList forKey:user];
        }];

        successBlock(resultDictionary);
    } onFailure:failureBlock];
}

- (void)deleteToken:(id)token onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSString *tokenString = [self tokenStringFromToken:token];
    NSString *type = [self tokenTypeFromToken:token];
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:tokenString, @"token", type, @"type", nil];
    NSURLRequest *request = [self.oauthClient requestWithMethod:@"POST" path:@"remove_token_universal" parameters:args];
    
    [self enqueueRequest:request onSuccess:^(NSDictionary *results) {successBlock();} onFailure:failureBlock];
}

- (void)enqueueRequest:(NSURLRequest *)request onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    AFJSONRequestOperation *op = [SMJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *urlRequest, NSHTTPURLResponse *response, id JSON) {
        successBlock(JSON);
    }failure:^(NSURLRequest *urlRequest, NSHTTPURLResponse *response, NSError *error, id JSON) {
        failureBlock([NSError errorWithDomain:@"SMError" code:[response statusCode] userInfo:JSON]);
    }];
    [self.oauthClient enqueueHTTPRequestOperation:op];  
}


+ (void)setDefaultClient:(SMPushClient *)client
{
    defaultClient = client;
}

+ (SMPushClient *)defaultClient
{
    return defaultClient;
}

@end

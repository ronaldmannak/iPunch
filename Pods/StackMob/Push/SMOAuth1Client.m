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

/*
 The following code was inspired by STLOAuthClient
 */

//
//  STLOAuthClient.h
//
//  Created by Marcelo Alves on 07/04/12.
//  Copyright (c) 2012 Some Time Left. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer. Redistributions in binary
//  form must reproduce the above copyright notice, this list of conditions and
//  the following disclaimer in the documentation and/or other materials
//  provided with the distribution. Neither the name of the Some Time Left nor
//  the names of its contributors may be used to endorse or promote products
//  derived from this software without specific prior written permission. THIS
//  SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#include <sys/time.h>
#import <CommonCrypto/CommonHMAC.h>
#import "SMOAuth1Client.h"
#import "Base64EncodedStringFromData.h"
#define SERVER_TIME_DIFF_KEY @"serverTimeDiff"

static NSString* URLEncodeString(NSString *string);

@interface SMOAuth1Client()
@property (copy) NSString *consumerKey;
@property (copy) NSString *consumerSecret;
@property (copy) NSString *tokenIdentifier;
@property (copy) NSString *tokenSecret;
@property (nonatomic, readwrite) NSTimeInterval serverTimeDiff;
@property (nonatomic, retain) NSDate *nextTimeCheck;

- (id) initWithBaseURL:(NSURL *)url;
- (void) addGeneratedTimestampAndNonceInto:(NSMutableDictionary *)dictionary;

- (NSString *) authorizationHeaderValueForRequest:(NSURLRequest *)request;

@end

@implementation SMOAuth1Client
@synthesize consumerKey = _consumerKey,
consumerSecret = _consumerSecret,
tokenSecret = _tokenSecret,
tokenIdentifier = _tokenIdentifier,
signRequests = _signRequests,
realm = _realm,
serverTimeDiff = _serverTimeDiff,
nextTimeCheck = _nextTimeCheck;

- (id) initWithBaseURL:(NSURL *)url consumerKey:(NSString *)consumerKey secret:(NSString *)consumerSecret {
    self = [super initWithBaseURL:url];
    
    if (self) {
        self.signRequests = YES;
        self.consumerKey = consumerKey;
        self.consumerSecret = consumerSecret;
        self.serverTimeDiff = [[NSUserDefaults standardUserDefaults] doubleForKey:SERVER_TIME_DIFF_KEY];
        self.nextTimeCheck = [NSDate date];
    }
    
    return self;
}

- (id) initWithBaseURL:(NSURL *)url {
    return [self initWithBaseURL:url consumerKey:NULL secret:NULL];
}

- (void) setAccessToken:(NSString *)accessToken secret:(NSString *)secret {
    self.tokenIdentifier = accessToken;
    self.tokenSecret = secret;
}

- (void) setConsumerKey:(NSString *)consumerKey secret:(NSString *)secret {
    self.consumerKey = consumerKey;
    self.consumerSecret = secret;
}

- (NSMutableURLRequest *) requestWithMethod:(NSString *)method
                                       path:(NSString *)path
                                 parameters:(NSDictionary *)parameters {
    
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    
    if (self.signRequests) {
        NSString *authorizationHeader = [self authorizationHeaderValueForRequest:request];
        [request setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
    }
    
    return request;
}

- (NSURLRequest *) unsignedRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    
    return request;
}

- (NSURLRequest *) signedRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    
    NSString *authorizationHeader = [self authorizationHeaderValueForRequest:request];
    [request setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
    
    return request;
}

#pragma mark - "private" methods.

static const NSString *kOAuthSignatureMethodKey = @"oauth_signature_method";
static const NSString *kOAuthVersionKey = @"oauth_version";
static const NSString *kOAuthConsumerKey = @"oauth_consumer_key";
static const NSString *kOAuthTokenIdentifier = @"oauth_token";
static const NSString *kOAuthSignatureKey = @"oauth_signature";

static const NSString *kOAuthSignatureTypeHMAC_SHA1 = @"HMAC-SHA1";
static const NSString *kOAuthVersion1_0 = @"1.0";

- (NSMutableDictionary *) mutableDictionaryWithOAuthInitialData {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   kOAuthSignatureTypeHMAC_SHA1, kOAuthSignatureMethodKey,
                                   kOAuthVersion1_0, kOAuthVersionKey,
                                   nil];
    
    if (self.consumerKey) [result setObject:self.consumerKey forKey:kOAuthConsumerKey];
    if (self.tokenIdentifier) [result setObject:self.tokenIdentifier forKey:kOAuthTokenIdentifier];
    
    [self addGeneratedTimestampAndNonceInto:result];
    
    return  result;
}

- (NSString *) stringWithOAuthParameters:(NSMutableDictionary *)oauthParams requestParameters:(NSDictionary *)parameters {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:oauthParams];
    [params addEntriesFromDictionary:parameters];
    
    // sorting parameters
    NSArray *sortedKeys = [[params allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
        NSComparisonResult result = [key1 compare:key2 options:NSLiteralSearch];
        if (result == NSOrderedSame)
            result = [[params objectForKey:key1] compare:[params objectForKey:key2] options:NSLiteralSearch];
        
        return result;
    }];
    
    // join keys and values with =
    NSMutableArray *longListOfParameters = [NSMutableArray arrayWithCapacity:[sortedKeys count]];
    [sortedKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        [longListOfParameters addObject:[NSString stringWithFormat:@"%@=%@", key, [params objectForKey:key]]];
    }];
    
    // join components with &
    return [longListOfParameters componentsJoinedByString:@"&"];
}

- (NSString *) authorizationHeaderValueForRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    NSString *fixedURL = [self baseURLforAddress:url];
    NSMutableDictionary *oauthParams = [self mutableDictionaryWithOAuthInitialData];
    
    // adding oauth_ extra params to the header
    NSArray *parameterComponents = [[request.URL query] componentsSeparatedByString:@"&"];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterComponents count]];
    for(NSString *component in parameterComponents) {
        NSArray *subComponents = [component componentsSeparatedByString:@"="];
        if ([subComponents count] == 2) {
            [parameters setObject:[subComponents objectAtIndex:1] forKey:[subComponents objectAtIndex:0]];
        }
    }
    
    NSString *allParameters = [self stringWithOAuthParameters:oauthParams requestParameters:parameters];
    // adding HTTP method and URL
    NSString *signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@", [request.HTTPMethod uppercaseString], URLEncodeString(fixedURL), URLEncodeString(allParameters)];
    
    NSString *signature = [self signatureForBaseString:signatureBaseString];
    
    // add to OAuth params
    [oauthParams setObject:signature forKey:kOAuthSignatureKey];
    
    // build OAuth Authorization Header
    NSMutableArray *headerParams = [NSMutableArray arrayWithCapacity:[oauthParams count]];
    [oauthParams enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [headerParams addObject:[NSString stringWithFormat:@"%@=\"%@\"", key, URLEncodeString(obj)]];
    }];
    
    // let's use the base URL if a realm was not set
    NSString *oauthRealm = self.realm;
    if (!oauthRealm) oauthRealm = [self baseURLforAddress:[self baseURL]];
    
    NSString *result = [NSString stringWithFormat:@"OAuth realm=\"%@\",%@", oauthRealm, [headerParams componentsJoinedByString:@","]];
    
    return result;
}

- (void)addGeneratedTimestampAndNonceInto:(NSMutableDictionary *)dictionary {
    
    NSString *timestamp = [NSString stringWithFormat:@"%ld", (long) [[self getServerTime] timeIntervalSince1970]];
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    NSString *nonce = (__bridge_transfer NSString *)string;
    CFRelease(theUUID);
    
    [dictionary setObject:nonce forKey:@"oauth_nonce"];
    [dictionary setObject:timestamp forKey:@"oauth_timestamp"];
}

- (NSString *) signatureForBaseString:(NSString *)baseString {
    NSString *key = [NSString stringWithFormat:@"%@&%@", self.consumerSecret != nil ? URLEncodeString(self.consumerSecret) : @"", self.tokenSecret != nil ? URLEncodeString(self.tokenSecret) : @""];
    
    const char *keyBytes = [key cStringUsingEncoding:NSUTF8StringEncoding];
    
    const char *baseStringBytes = [baseString cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char digestBytes[CC_SHA1_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA1, keyBytes, strlen(keyBytes), baseStringBytes, strlen(baseStringBytes), digestBytes);
    
    NSData *digestData = [NSData dataWithBytes:digestBytes length:CC_SHA1_DIGEST_LENGTH];
    return Base64EncodedStringFromData(digestData);
}

- (NSString *) baseURLforAddress:(NSURL *)url {
    NSAssert1([url host] != nil, @"URL host missing: %@", [url absoluteString]);
    
    // Port need only be present if it's not the default
    NSString *hostString;
    if (([url port] == nil)
        || ([[[url scheme] lowercaseString] isEqualToString:@"http"] && ([[url port] integerValue] == 80))
        || ([[[url scheme] lowercaseString] isEqualToString:@"https"] && ([[url port] integerValue] == 443))) {
        hostString = [[url host] lowercaseString];
    } else {
        hostString = [NSString stringWithFormat:@"%@:%@", [[url host] lowercaseString], [url port]];
    }
    
    return [NSString stringWithFormat:@"%@://%@%@", [[url scheme] lowercaseString], hostString, [[url absoluteURL] path]];
}

- (NSDate *)getServerTime {
    return [NSDate dateWithTimeIntervalSinceNow:self.serverTimeDiff];
}

- (void)recordServerTimeDiffFromHeader:(NSString*)header {
    if (header != nil) {
        
        NSDateFormatter *rfcFormatter = [[NSDateFormatter alloc] init];
        [rfcFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
        NSDate *serverTime = [rfcFormatter dateFromString:header];
        self.serverTimeDiff = [serverTime timeIntervalSinceDate:[NSDate date]];
        if([[NSDate date] earlierDate:_nextTimeCheck] == _nextTimeCheck) {
            // Save the date to persistent storage every ten minutes
            [[NSUserDefaults standardUserDefaults] setDouble:self.serverTimeDiff forKey:SERVER_TIME_DIFF_KEY];
            self.nextTimeCheck = [NSDate dateWithTimeIntervalSinceNow:10 * 60];
        }
    }
}

@end


#pragma mark - Helper Functions
//
//  The function below is based on
//
//  NSString+URLEncode.h
//
//  Created by Scott James Remnant on 6/1/11.
//  Copyright 2011 Scott James Remnant <scott@netsplit.com>. All rights reserved.
//
static NSString *URLEncodeString(NSString *string) {
    // See http://en.wikipedia.org/wiki/Percent-encoding and RFC3986
    // Hyphen, Period, Understore & Tilde are expressly legal
    const CFStringRef legalURLCharactersToBeEscaped = CFSTR("!*'();:@&=+$,/?#[]<>\"{}|\\`^% ");
    
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, legalURLCharactersToBeEscaped, kCFStringEncodingUTF8);
}

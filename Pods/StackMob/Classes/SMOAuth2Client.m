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

#import "SMOAuth2Client.h"
#import <CommonCrypto/CommonHMAC.h>
#import "SMVersion.h"
#import "SMCustomCodeRequest.h"
#import "SMRequestOptions.h"
#import "Base64EncodedStringFromData.h"
#import "SystemInformation.h"
#import "SMError.h"

@implementation SMOAuth2Client

@synthesize version = _SM_version;
@synthesize publicKey = _SM_publicKey;
@synthesize apiHost = _SM_apiHost;
@synthesize accessToken = _SM_accessToken;
@synthesize macKey = _SM_macKey;

- (id)initWithAPIVersion:(NSString *)version
                   scheme:(NSString *)scheme
                  apiHost:(NSString *)apiHost 
                publicKey:(NSString *)publicKey 
{
    self = [super initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", scheme, apiHost]]];
    
    if (self) {
        self.version = version;
        self.publicKey = publicKey;
        NSString *acceptHeader = [NSString stringWithFormat:@"application/vnd.stackmob+json; version=%@", version];
        [self setDefaultHeader:@"Accept" value:acceptHeader]; 
        [self setDefaultHeader:@"X-StackMob-API-Key" value:self.publicKey];
        [self setDefaultHeader:@"User-Agent" value:[NSString stringWithFormat:@"StackMob/%@ (%@/%@; %@;)", SDK_VERSION, smDeviceModel(), smSystemVersion(), [[NSLocale currentLocale] localeIdentifier]]];
        self.parameterEncoding = AFJSONParameterEncoding;
    }
    return self;
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method 
                                       path:(NSString *)path 
                                 parameters:(NSDictionary *)parameters
{
    
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    if ([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"]) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    [self signRequest:request path:[NSString stringWithFormat:@"/%@", path]];
    return request;
}

- (NSMutableURLRequest *)customCodeRequest:(SMCustomCodeRequest *)aRequest options:(SMRequestOptions *)options
{
    NSURL *url = [NSURL URLWithString:aRequest.method relativeToURL:self.baseURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    [request setHTTPMethod:aRequest.httpVerb];
    
    // Set accept headers here
    if (options.headers && [options.headers count] > 0) {
        // Enumerate through options and add them to the request header.
        [options.headers enumerateKeysAndObjectsUsingBlock:^(id headerField, id headerValue, BOOL *stop) {
            
            // Error checks for functionality not supported
            if ([headerField isEqualToString:@"X-StackMob-Expand"]) {
                if ([[request HTTPMethod] isEqualToString:@"POST"] || [[request HTTPMethod] isEqualToString:@"PUT"]) {
                    [NSException raise:SMExceptionIncompatibleObject format:@"Expand depth is not supported for creates or updates.  Please check your requests and edit accordingly."];
                }
            }
            
            [request setValue:headerValue forHTTPHeaderField:headerField];
        }];
        
        // Set the headers dictionary to empty, to prevent unnecessary enumeration during recursion.
        options.headers = [NSDictionary dictionary];
    }
    
    // Set Accept header if needed
    if ([[[request allHTTPHeaderFields] allKeys] indexOfObject:@"Accept"] == NSNotFound) {
        NSString *acceptHeader = [NSString stringWithFormat:@"application/vnd.stackmob+json; version=%@", self.version];
        [request setValue:acceptHeader forHTTPHeaderField:@"Accept"];
    }
    
    [request setValue:self.publicKey forHTTPHeaderField:@"X-StackMob-API-Key"];
    [request setValue:[NSString stringWithFormat:@"StackMob/%@ (%@/%@; %@;)", SDK_VERSION, smDeviceModel(), smSystemVersion(), [[NSLocale currentLocale] localeIdentifier]] forHTTPHeaderField:@"User-Agent"];
	
    if ([aRequest.queryStringParameters count] > 0) {
        url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:[aRequest.method rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@", [aRequest.queryStringParameters componentsJoinedByString:@"&"]]];
        [request setURL:url];
    }
    
    if (aRequest.requestBody) {
        [request setHTTPBody:[aRequest.requestBody dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [self signRequest:request path:[[request URL] path]];
    return request;
}

- (void)signRequest:(NSMutableURLRequest *)request path:(NSString *)path
{
    if ([self hasValidCredentials]) {
        static NSString * const charactersToLeaveEscaped = @":/.?&=;+!@#$()~ ";
        NSString *decodedQuery = (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, (__bridge CFStringRef)[[request URL] query], (__bridge CFStringRef)(charactersToLeaveEscaped), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
        NSString *queryString = [[[request URL] query] length] == 0 ? @"" : [NSString stringWithFormat:@"?%@", decodedQuery];
        NSString *pathAndQuery = [NSString stringWithFormat:@"%@%@", path, queryString];
        NSString *macHeader = [self createMACHeaderForHttpMethod:[request HTTPMethod] path:pathAndQuery];
        [request setValue:macHeader forHTTPHeaderField:@"Authorization"];
    }
}

- (BOOL)hasValidCredentials
{
    return self.accessToken != nil && self.macKey != nil;
}

- (NSString *) getPort
{
    if ([[self baseURL] port] != nil) {
        return [[[self baseURL] port] stringValue];
    } else if ([[[self baseURL] scheme] hasPrefix:@"https"]) {
        return @"443";
    } else {
        return @"80";
    }
}

- (NSString *)createMACHeaderForHttpMethod:(NSString *)method path:(NSString *)path timestamp:(double)timestamp nonce:(NSString *)nonce
{

    NSString *host = [[self baseURL] host];
    NSString *port = [self getPort];
    
    // create base
    NSArray *baseArray = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%.f", timestamp], nonce, method, path, host, port, nil];
    unichar newline = 0x0A;
    NSString *baseString = [baseArray componentsJoinedByString:[NSString stringWithFormat:@"%C", newline]];
    baseString = [baseString stringByAppendingString:[NSString stringWithFormat:@"%C", newline]];
    baseString = [baseString stringByAppendingString:[NSString stringWithFormat:@"%C", newline]];
    
    const char *keyCString = [self.macKey cStringUsingEncoding:NSUTF8StringEncoding];
    const char *baseCString = [baseString cStringUsingEncoding:NSUTF8StringEncoding];
    
    
    char buffer[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, keyCString, strlen(keyCString), baseCString, strlen(baseCString), buffer); 
    NSData *digestData = [NSData dataWithBytes:buffer length:CC_SHA1_DIGEST_LENGTH];
    NSString *mac = Base64EncodedStringFromData(digestData); 
    //return 'MAC id="' + id + '",ts="' + ts + '",nonce="' + nonce + '",mac="' + mac + '"'
    unichar quotes = 0x22;
    NSString *returnString = [NSString stringWithFormat:@"MAC id=%C%@%C,ts=%C%.f%C,nonce=%C%@%C,mac=%C%@%C", quotes, self.accessToken, quotes, quotes, timestamp, quotes, quotes, nonce, quotes, quotes, mac, quotes];
    return returnString; 
}


- (NSString *)createMACHeaderForHttpMethod:(NSString *)method path:(NSString *)path
{
    return [self createMACHeaderForHttpMethod:method path:path timestamp:[[NSDate date] timeIntervalSince1970] nonce:[NSString stringWithFormat:@"n%d", arc4random() % 10000]];
}

@end

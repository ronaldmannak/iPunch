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

#import "SMRequestOptions.h"

@implementation SMRequestOptions

@synthesize headers = _SM_headers;
@synthesize isSecure = _SM_isSecure;
@synthesize tryRefreshToken = _SM_tryRefreshToken;
@synthesize numberOfRetries = _SM_numberOfRetries;
@synthesize retryBlock = _SM_retryBlock;


+ (SMRequestOptions *)options
{
    SMRequestOptions *opts = [[SMRequestOptions alloc] init];
    opts.headers = nil;
    opts.isSecure = NO;
    opts.tryRefreshToken = YES;
    opts.numberOfRetries = 3;
    opts.retryBlock = nil;
    return opts;
}

+ (SMRequestOptions *)optionsWithHeaders:(NSDictionary *)headers
{
    SMRequestOptions *opt = [SMRequestOptions options];
    opt.headers = headers;
    return opt;
}


+ (SMRequestOptions *)optionsWithHTTPS
{
    SMRequestOptions *opt = [SMRequestOptions options];
    opt.isSecure = YES;
    return opt;
}

+ (SMRequestOptions *)optionsWithExpandDepth:(NSUInteger)depth
{
    SMRequestOptions *opt = [SMRequestOptions options];
    [opt setExpandDepth:depth];
    return opt;
}

+ (SMRequestOptions *)optionsWithReturnedFieldsRestrictedTo:(NSArray *)fields
{
    SMRequestOptions *opt = [SMRequestOptions options];
    [opt restrictReturnedFieldsTo:fields];
    return opt;
}

- (void)setExpandDepth:(NSUInteger)depth
{
    if (!self.headers) {
        self.headers = [NSDictionary dictionary];
    }
    NSMutableDictionary *tempHeadersDict = [self.headers mutableCopy];
    [tempHeadersDict setValue:[NSString stringWithFormat:@"%d", (int)depth] forKey:@"X-StackMob-Expand"];
    self.headers = tempHeadersDict;
}

- (void)restrictReturnedFieldsTo:(NSArray *)fields
{
    if (!self.headers) {
        self.headers = [NSDictionary dictionary];
    }
    NSMutableDictionary *tempHeadersDict = [self.headers mutableCopy];
    [tempHeadersDict setValue:[fields componentsJoinedByString:@","] forKey:@"X-StackMob-Select"];
    self.headers = tempHeadersDict;
}

- (void)addSMErrorServiceUnavailableRetryBlock:(SMFailureRetryBlock)retryBlock
{
    self.retryBlock = retryBlock;
}

@end

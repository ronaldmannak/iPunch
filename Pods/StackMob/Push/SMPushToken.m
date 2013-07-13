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

#import "SMPushToken.h"

@implementation SMPushToken

@synthesize tokenString = _SM_tokenString;
@synthesize type = _SM_type;
@synthesize registrationTime = _SM_registrationTime;

-(id)initWithString:(NSString *)tokenString
{
    return [self initWithString:tokenString type:TOKEN_TYPE_IOS];
}

-(id)initWithString:(NSString *)tokenString type:(NSString *)type
{
    self = [self init];
    if (self)
    {
        self.tokenString = tokenString;
        self.type = type;
    }
    return self;
}


@end

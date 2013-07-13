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

#import "SMBinaryDataConversion.h"
#import <CommonCrypto/CommonHMAC.h>
#import "Base64EncodedStringFromData.h"
#import "SMError.h"

@implementation SMBinaryDataConversion

+ (NSString *)stringForBinaryData:(NSData *)data name:(NSString *)name contentType:(NSString *)contentType
{
    
    return [NSString stringWithFormat:@"Content-Type: %@\n"
            "Content-Disposition: attachment; filename=%@\n"
            "Content-Transfer-Encoding: %@\n\n"
            "%@",
            contentType,
            name,
            @"base64",
            Base64EncodedStringFromData(data)];
}

+ (NSData *)dataForString:(NSString *)string
{
    NSArray *components = [string componentsSeparatedByString:@"base64"];
    if ([components count] != 2) {
        [NSException raise:SMExceptionIncompatibleObject format:@"String to be converted to data is not in the correct form.  Make sure this method is only called on attributes which map to binary fields on StackMob and have not yet been saved."];
    }
    
    NSString *stringToDecode = components[1];
    NSData *dataToReturn = Base64DecodedDataFromString(stringToDecode);
    
    return dataToReturn;
    
}

+ (BOOL)stringContainsURL:(NSString *)value
{
    NSRange range = [value rangeOfString:@"Content-Type"];
    return range.location == NSNotFound;
}

@end

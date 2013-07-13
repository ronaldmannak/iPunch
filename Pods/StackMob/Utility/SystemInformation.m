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

#import "SystemInformation.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>

NSString * smDeviceModel()
{
    return [[UIDevice currentDevice] model];
}

NSString * smSystemVersion()
{
    return [[UIDevice currentDevice] systemVersion];
}

#else

#include <sys/types.h>
#include <sys/sysctl.h>

NSString * smDeviceModel()
{
    NSString* deviceModel = @"Unknown";
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        deviceModel = [NSString stringWithCString:model encoding:NSASCIIStringEncoding];
        free(model);
    }
    return deviceModel;
}

NSString * smSystemVersion()
{
    NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    return [systemVersionDictionary objectForKey:@"ProductVersion"];
}

#endif
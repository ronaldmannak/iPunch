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

#import "SMSyncedObject.h"

@implementation SMSyncedObject
@synthesize objectID = _objectID;
@synthesize actionTaken = _actionTaken;

- (id)initWithObjectID:(id)objectID actionTaken:(SMSyncAction)actionTaken
{
    self = [super init];
    if (self) {
        if ([objectID isKindOfClass:[NSManagedObjectID class]]) {
            self.objectID = (NSManagedObjectID *)objectID;
        } else {
            self.objectID = (NSString *)objectID;
        }
        self.actionTaken = actionTaken;
    }
    
    return self;
}

@end

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

#import "SMUserManagedObject.h"
#import "StackMob.h"
#import "KeychainWrapper.h"
#import "NSManagedObject+StackMobSerialization.h"

@interface SMUserManagedObject ()

@property (nonatomic, readwrite) SMClient *client;

@end

@implementation SMUserManagedObject

@synthesize client = _client;

- (id)initWithEntityName:(NSString *)entityName insertIntoManagedObjectContext:(NSManagedObjectContext *)context
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    return [self initWithEntity:entity client:[SMClient defaultClient] insertIntoManagedObjectContext:context];
}

- (id)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context
{
    return [self initWithEntity:entity client:[SMClient defaultClient] insertIntoManagedObjectContext:context];
}

- (id)initWithEntity:(NSEntityDescription *)entity client:(SMClient *)client insertIntoManagedObjectContext:(NSManagedObjectContext *)context
{
    self = [super initWithEntity:entity insertIntoManagedObjectContext:context];
    if (self) {
        self.client = client;
    }
    
    return self;
}

- (NSString *)primaryKeyField
{
    return self.client.userPrimaryKeyField;
}

- (void)setPassword:(NSString *)value
{
    NSString *serviceName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleIdentifierKey];
    if (serviceName == nil) {
        serviceName = @"com.stackmob.passwordstore";
    }
    NSString *passwordIdentifier = [[serviceName stringByAppendingPathExtension:[NSString stringWithFormat:@"%d", arc4random() / 1000]] stringByAppendingPathExtension:@"password"];
    if (![KeychainWrapper createKeychainValue:value forIdentifier:passwordIdentifier]) {
        [NSException raise:@"SMKeychainSaveUnsuccessful" format:@"Password could not be saved to keychain"];
    }
    
    [self.client.session.userIdentifierMap setObject:passwordIdentifier forKey:[self valueForKey:[self primaryKeyField]]];
    [self.client.session SMSaveUserIdentifierMap];
    
}

- (void)removePassword
{
    NSString *primaryKeyValue = [self valueForKey:[self primaryKeyField]];
    NSString *passwordIdentifier = [self.client.session.userIdentifierMap objectForKey:primaryKeyValue];
    if (passwordIdentifier) {
        [self.client.session.userIdentifierMap removeObjectForKey:primaryKeyValue];
        [KeychainWrapper deleteItemFromKeychainWithIdentifier:passwordIdentifier];
        [self.client.session SMSaveUserIdentifierMap];
    }
    
}



@end

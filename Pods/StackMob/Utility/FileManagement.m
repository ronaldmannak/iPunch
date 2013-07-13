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

#import "FileManagement.h"
#import "SMIncrementalStore.h"
#import "SMCoreDataStore.h"
#import "SMUserSession.h"
#import "SMOAuth2Client.h"
#import "SMError.h"
#import "Common.h"

@implementation FileManagement

+ (void)SM_createStoreURLPathIfNeeded:(NSURL *)storeURL
{
    if (SM_CORE_DATA_DEBUG) {DLog()}
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *pathToStore = [storeURL URLByDeletingLastPathComponent];
    BOOL isDir;
    BOOL fileExists = [fileManager fileExistsAtPath:[pathToStore path] isDirectory:&isDir];
    if (!fileExists) {
        NSError *error = nil;
        BOOL pathWasCreated = [fileManager createDirectoryAtPath:[pathToStore path] withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (!pathWasCreated) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating sqlite persistent store: %@", error];
        }
    }
    
}

+ (void)SM_removeStoreURLPath:(NSURL *)storeURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[storeURL path]]) {
        NSError *deleteError = nil;
        BOOL delete = [fileManager removeItemAtURL:storeURL error:&deleteError];
        if (!delete) {
            [NSException raise:@"SMExceptionCouldNotDeleteSQLiteDatabase" format:@""];
        }
    }
}

+ (NSURL *)SM_getStoreURLForFileComponent:(NSString *)fileComponent coreDataStore:(SMCoreDataStore *)coreDataStore
{
    if (SM_CORE_DATA_DEBUG) {DLog()}
    
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *applicationDocumentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
    
    NSString *fullFileName = nil;
    if (applicationName != nil)
    {
        fullFileName = [NSString stringWithFormat:@"%@-%@-%@", applicationName, coreDataStore.session.regularOAuthClient.publicKey, fileComponent];
    } else {
        fullFileName = [NSString stringWithFormat:@"%@-%@", coreDataStore.session.regularOAuthClient.publicKey, fileComponent];
    }
    
    
    NSArray *paths = [NSArray arrayWithObjects:applicationDocumentsDirectory, applicationStorageDirectory, nil];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    for (NSString *path in paths)
    {
        NSString *filepath = [path stringByAppendingPathComponent:fullFileName];
        if ([fm fileExistsAtPath:filepath])
        {
            return [NSURL fileURLWithPath:filepath];
        }
        
    }
    
    NSURL *aURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:fullFileName]];
    return aURL;
}

@end

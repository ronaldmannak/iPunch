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

#import "NSManagedObjectContext+Concurrency.h"
#import "SMClient.h"

@implementation NSManagedObjectContext (Concurrency)

- (void)dealloc
{
    [self setContextShouldObtainPermanentIDsBeforeSaving:NO];
}

- (void)observeContext:(NSManagedObjectContext *)contextToObserve
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SM_mergeChangesFromNotification:) name:NSManagedObjectContextDidSaveNotification object:contextToObserve];
}

- (void)stopObservingContext:(NSManagedObjectContext *)contextToStopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:contextToStopObserving];
}

- (void)SM_mergeChangesFromNotification:(NSNotification *)notification
{
    [self mergeChangesFromContextDidSaveNotification:notification];
}

- (void)setContextShouldObtainPermanentIDsBeforeSaving:(BOOL)value
{
    if (value) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contextWillSave:)
                                                     name:NSManagedObjectContextWillSaveNotification
                                                   object:self];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextWillSaveNotification object:self];
    }
}

- (void)contextWillSave:(NSNotification *)notification
{
    NSManagedObjectContext *context = (NSManagedObjectContext *)notification.object;
    if (context.insertedObjects.count > 0) {
        NSArray *insertedObjects = [[context insertedObjects] allObjects];
        NSError *error = nil;
        [context obtainPermanentIDsForObjects:insertedObjects error:&error];
    }
}

- (void)saveOnSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self saveWithSuccessCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)saveWithSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self saveWithSuccessCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue options:nil onSuccess:successBlock onFailure:failureBlock];
}

- (void)saveWithSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue options:(SMRequestOptions *)options onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSManagedObjectContext *mainContext = nil;
    NSManagedObjectContext *temporaryContext = nil;
    if ([self concurrencyType] == NSMainQueueConcurrencyType) {
        mainContext = self;
        temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        temporaryContext.parentContext = mainContext;
    } else {
        temporaryContext = self;
        mainContext = temporaryContext.parentContext;
    }
    
    
    NSManagedObjectContext *privateContext = mainContext.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should be of type NSMainQueueConcurrencyType"];
    } else if (!privateContext) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should have parent with set persistent store coordinator"];
    }
    
    [temporaryContext performBlock:^{
        
        __block NSError *saveError;
        
        if (options) {
            SMRequestOptions *newOptions = options;
            NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
            [threadDict setObject:newOptions forKey:SMRequestSpecificOptions];
        }
        
        // Save Temporary Context
        BOOL tempContextSaveSuccess = [temporaryContext save:&saveError];
        
        if (options) {
            [[[NSThread currentThread] threadDictionary] removeObjectForKey:SMRequestSpecificOptions];
        }
        
        if (!tempContextSaveSuccess) {
            
            [self callFailureBlock:failureBlock queue:failureCallbackQueue error:saveError];
            
        } else {
            // Save Main Context
            [mainContext performBlock:^{
                
                if (options) {
                    SMRequestOptions *newOptions = options;
                    NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
                    [threadDict setObject:newOptions forKey:SMRequestSpecificOptions];
                }
                
                BOOL mainContextSaveSuccess = [mainContext save:&saveError];
                
                if (options) {
                    [[[NSThread currentThread] threadDictionary] removeObjectForKey:SMRequestSpecificOptions];
                }
                
                if (!mainContextSaveSuccess) {
                    
                    [self callFailureBlock:failureBlock queue:failureCallbackQueue error:saveError];
                    
                } else {
                    // Main Context should always have a private queue parent
                    if (privateContext) {
                        
                        // Save Private Context to disk
                        [privateContext performBlock:^{
                            
                            if (options) {
                                SMRequestOptions *newOptions = options;
                                NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
                                [threadDict setObject:newOptions forKey:SMRequestSpecificOptions];
                            }
                            
                            BOOL privateContextSaveSuccess = [privateContext save:&saveError];
                            
                            if (options) {
                                [[[NSThread currentThread] threadDictionary] removeObjectForKey:SMRequestSpecificOptions];
                            }
                            
                            if (!privateContextSaveSuccess) {
                                
                                [self callFailureBlock:failureBlock queue:failureCallbackQueue error:saveError];
                                
                            } else {
                                
                                // Dispatch success block to main thread
                                if (successBlock) {
                                    dispatch_async(successCallbackQueue, ^{
                                        successBlock();
                                    });
                                }
                                
                            }
                            
                        }];
                        
                    }
                }
                
            }];
            
        }
        
    }];
}

- (BOOL)saveAndWait:(NSError *__autoreleasing*)error
{
    return [self saveAndWait:error options:nil];
}

- (BOOL)saveAndWait:(NSError *__autoreleasing *)error options:(SMRequestOptions *)options
{
    
    NSManagedObjectContext *mainContext = nil;
    NSManagedObjectContext *temporaryContext = nil;
    if ([self concurrencyType] == NSMainQueueConcurrencyType) {
        mainContext = self;
        temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        temporaryContext.parentContext = mainContext;
    } else {
        temporaryContext = self;
        mainContext = temporaryContext.parentContext;
    }
    
    
    NSManagedObjectContext *privateContext = mainContext.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should be of type NSMainQueueConcurrencyType"];
    } else if (!privateContext) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should have parent with set persistent store coordinator"];
    }
    
    __block BOOL success = NO;
    __block NSError *saveError = nil;
    [temporaryContext performBlockAndWait:^{
        
        if (options) {
            SMRequestOptions *newOptions = options;
            NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
            [threadDict setObject:newOptions forKey:SMRequestSpecificOptions];
        }
        
        // Save Temporary Context
        if ([temporaryContext save:&saveError]) {
            
            // Save Main Context
            [mainContext performBlockAndWait:^{
                
                if ([mainContext save:&saveError]) {
                    
                    // Save Private Context to disk
                    [privateContext performBlockAndWait:^{
                        
                        if ([privateContext save:&saveError]) {

                            success = YES;
                        }
                        
                    }];
                    
                }
                
            }];
            
        }
        
    }];
    
    if (saveError != nil && error != NULL) {
        *error = saveError;
    }
    
    if (options) {
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:SMRequestSpecificOptions];
    }
    
    return success;
}

- (void)executeFetchRequest:(NSFetchRequest *)request onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self executeFetchRequest:request returnManagedObjectIDs:NO onSuccess:successBlock onFailure:failureBlock];
}

- (void)executeFetchRequest:(NSFetchRequest *)request returnManagedObjectIDs:(BOOL)returnIDs onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self executeFetchRequest:request returnManagedObjectIDs:returnIDs successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)executeFetchRequest:(NSFetchRequest *)request returnManagedObjectIDs:(BOOL)returnIDs successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self executeFetchRequest:request returnManagedObjectIDs:returnIDs successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue options:nil onSuccess:successBlock onFailure:failureBlock];
}

- (void)executeFetchRequest:(NSFetchRequest *)request returnManagedObjectIDs:(BOOL)returnIDs successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue options:(SMRequestOptions *)options onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    __block NSManagedObjectContext *mainContext = [self concurrencyType] == NSMainQueueConcurrencyType ? self : self.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method executeFetchRequest: main context should be of type NSMainQueueConcurrencyType"];
    }
    
    NSManagedObjectContext *backgroundContext = mainContext.parentContext;
    
    [backgroundContext performBlock:^{
        NSError *fetchError = nil;
        NSFetchRequest *fetchCopy = [request copy];
        [fetchCopy setResultType:NSManagedObjectIDResultType];
        
        if (options) {
            SMRequestOptions *newOptions = options;
            NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
            [threadDict setObject:newOptions forKey:SMRequestSpecificOptions];
        }
        
        __block NSArray *resultsOfFetch = [backgroundContext executeFetchRequest:fetchCopy error:&fetchError];
        
        if (options) {
            [[[NSThread currentThread] threadDictionary] removeObjectForKey:SMRequestSpecificOptions];
        }
        
        if (fetchError) {
            [self callFailureBlock:failureBlock queue:failureCallbackQueue error:fetchError];
        } else {
            if (successBlock) {
                if (returnIDs) {
                    dispatch_async(successCallbackQueue, ^{
                        successBlock(resultsOfFetch);
                    });
                } else {
                    dispatch_async(successCallbackQueue, ^{
                        
                        NSManagedObjectContext *context = nil;
                        
                        if ([NSThread isMainThread]) {
                            context = mainContext;
                            
                        } else {
                            context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
                            [context setPersistentStoreCoordinator:[backgroundContext persistentStoreCoordinator]];
                            
                        }
                        
                        __block NSArray *managedObjectsToReturn = [resultsOfFetch map:^id(id item) {
                            NSManagedObject *objectFromCurrentContext = [context objectWithID:item];
                            [context refreshObject:objectFromCurrentContext mergeChanges:YES];
                            return objectFromCurrentContext;
                        }];
                        
                        successBlock(managedObjectsToReturn);
                        
                    });
                }
            }
        }
        
    }];
    
}

- (NSArray *)executeFetchRequestAndWait:(NSFetchRequest *)request error:(NSError *__autoreleasing *)error
{
    return [self executeFetchRequestAndWait:request returnManagedObjectIDs:NO error:error];
}

- (NSArray *)executeFetchRequestAndWait:(NSFetchRequest *)request returnManagedObjectIDs:(BOOL)returnIDs error:(NSError *__autoreleasing *)error
{
    return [self executeFetchRequestAndWait:request returnManagedObjectIDs:returnIDs options:nil error:error];
}

- (NSArray *)executeFetchRequestAndWait:(NSFetchRequest *)request returnManagedObjectIDs:(BOOL)returnIDs options:(SMRequestOptions *)options error:(NSError *__autoreleasing *)error
{
    __block NSManagedObjectContext *mainContext = [self concurrencyType] == NSMainQueueConcurrencyType ? self : self.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method executeFetchRequestAndWait: main context should be of type NSMainQueueConcurrencyType"];
    }
    
    __block NSArray *resultsOfFetch = nil;
    __block NSError *fetchError = nil;
    
    NSManagedObjectContext *backgroundContext = mainContext.parentContext;
    NSFetchRequest *fetchCopy = [request copy];
    [fetchCopy setResultType:NSManagedObjectIDResultType];
    
    if ([request fetchBatchSize] > 0) {
        [fetchCopy setFetchBatchSize:[request fetchBatchSize]];
    }
    
    [backgroundContext performBlockAndWait:^{
        
        if (options) {
            SMRequestOptions *newOptions = options;
            NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
            [threadDict setObject:newOptions forKey:SMRequestSpecificOptions];
        }
        
        resultsOfFetch = [backgroundContext executeFetchRequest:fetchCopy error:&fetchError];
        
        if (options) {
            [[[NSThread currentThread] threadDictionary] removeObjectForKey:SMRequestSpecificOptions];
        }
    }];
    
    if (fetchError && error != NULL) {
        *error = fetchError;
        return nil;
    }
    
    if (returnIDs) {
        return resultsOfFetch;
    } else {
        return [resultsOfFetch map:^id(id item) {
            NSManagedObject *objectFromCurrentContext = [self objectWithID:item];
            [self refreshObject:objectFromCurrentContext mergeChanges:YES];
            return objectFromCurrentContext;
        }];
    }
}

- (void)callFailureBlock:(SMFailureBlock)failureBlock queue:(dispatch_queue_t)queue error:(NSError *)saveError {
    
    if ([saveError code] == SMErrorRefreshTokenFailed) {
        NSDictionary *userInfo = [saveError userInfo];
        SMTokenRefreshFailureBlock tokenRefreshBlock = [userInfo objectForKey:SMFailedRefreshBlock];
        if (tokenRefreshBlock) {
            // Remove refresh block from userInfo
            NSMutableDictionary *newUserInfo = [userInfo mutableCopy];
            [newUserInfo removeObjectForKey:SMFailedRefreshBlock];
            NSError *newError = [NSError errorWithDomain:[saveError domain] code:[saveError code] userInfo:newUserInfo];
            tokenRefreshBlock(newError, failureBlock);
        } else {
            if (failureBlock) {
                dispatch_async(queue, ^{
                    failureBlock(saveError);
                });
            }
        }
    } else if (failureBlock) {
        dispatch_async(queue, ^{
            failureBlock(saveError);
        });
    }
}

@end

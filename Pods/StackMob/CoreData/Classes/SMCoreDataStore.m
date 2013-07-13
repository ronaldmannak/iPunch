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

#import "SMCoreDataStore.h"
#import "SMIncrementalStore.h"
#import "SMError.h"
#import "NSManagedObjectContext+Concurrency.h"
#import "FileManagement.h"
#import "Common.h"

static NSString *const SM_ManagedObjectContextKey = @"SM_ManagedObjectContextKey";
NSString *const SMSetCachePolicyNotification = @"SMSetCachePolicyNotification";
NSString *const SMDirtyQueueNotification = @"SMDirtyQueueNotification";

BOOL SM_CACHE_ENABLED = NO;

SMMergePolicy const SMMergePolicyClientWins = ^(NSDictionary *clientObject, NSDictionary *serverObject, NSDate *serverBaseLastModDate){
    
    return SMClientObject;
    
};

SMMergePolicy const SMMergePolicyLastModifiedWins = ^(NSDictionary *clientObject, NSDictionary *serverObject, NSDate *serverBaseLastModDate){
    
    double clientLastModDate = [[clientObject objectForKey:SMLastModDateKey] timeIntervalSince1970];
    double serverLastModDate = [[serverObject objectForKey:SMLastModDateKey] timeIntervalSince1970];
    if (SM_CORE_DATA_DEBUG) { DLog(@"client lmd is %f and server lmd is %f", clientLastModDate, serverLastModDate) }
    
    if (clientLastModDate > serverLastModDate) {
        return SMClientObject;
    } else if (clientLastModDate < serverLastModDate) {
        return SMServerObject;
    } else {
        if (!serverLastModDate) {
            return SMClientObject;
        } else {
            // Dates are actually the same, default to server
            return SMServerObject;
        }
    }
    
};

SMMergePolicy const SMMergePolicyServerModifiedWins = ^(NSDictionary *clientObject, NSDictionary *serverObject, NSDate *serverBaseLastModDate){
    
    NSDate *serverLastModDate = [serverObject objectForKey:SMLastModDateKey];
    if (![serverBaseLastModDate isEqualToDate:serverLastModDate]) {
        return SMServerObject;
    } else {
        return SMClientObject;
    }
};

@interface SMCoreDataStore ()

@property(nonatomic, readwrite, strong)NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSManagedObjectContext *privateContext;
@property (nonatomic, strong) id defaultCoreDataMergePolicy;
@property (nonatomic) dispatch_queue_t cachePurgeQueue;
@property (nonatomic, strong) NSArray *currentDirtyQueue;

- (NSManagedObjectContext *)SM_newPrivateQueueContextWithParent:(NSManagedObjectContext *)parent;
- (void)SM_didReceiveSetCachePolicyNotification:(NSNotification *)notification;

@end

@implementation SMCoreDataStore

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;
@synthesize mainThreadContext = _mainThreadContext;
@synthesize privateContext = _privateContext;
@synthesize defaultCoreDataMergePolicy = _defaultCoreDataMergePolicy;
@synthesize defaultSMMergePolicy = _defaultSMMergePolicy;
@synthesize cachePurgeQueue = _cachePurgeQueue;
@synthesize cachePolicy = _cachePolicy;
@synthesize globalRequestOptions = _globalRequestOptions;
@synthesize insertsSMMergePolicy = _insertsSMMergePolicy;
@synthesize updatesSMMergePolicy = _updatesSMMergePolicy;
@synthesize deletesSMMergePolicy = _deletesSMMergePolicy;
@synthesize syncCompletionCallback = _syncCompletionCallback;
@synthesize syncCallbackQueue = _syncCallbackQueue;
@synthesize syncInProgress = _syncInProgress;
@synthesize currentDirtyQueue = _currentDirtyQueue;
@synthesize sendLocalTimestamps = _sendLocalTimestamps;

- (id)initWithAPIVersion:(NSString *)apiVersion session:(SMUserSession *)session managedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
    self = [super initWithAPIVersion:apiVersion session:session];
    if (self) {
        _managedObjectModel = managedObjectModel;
        
        
        /// Init callback queues
        self.syncCallbackQueue = dispatch_get_main_queue();
        self.cachePurgeQueue = dispatch_queue_create("com.stackmob.cachePurgeQueue", NULL);
        
        /// Set default cache and merge policies
        [self setCachePolicy:SMCachePolicyTryNetworkOnly];
        _defaultCoreDataMergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        self.defaultSMMergePolicy = SMMergePolicyServerModifiedWins;
        self.insertsSMMergePolicy = nil;
        self.updatesSMMergePolicy = nil;
        self.deletesSMMergePolicy = nil;
        
        /// Init callbacks
        self.syncCallbackForFailedInserts = nil;
        self.syncCallbackForFailedUpdates = nil;
        self.syncCallbackForFailedDeletes = nil;
        self.syncCompletionCallback = nil;
        
        self.syncInProgress = NO;
        self.sendLocalTimestamps = NO;
        self.currentDirtyQueue = nil;
        
        /// Init global request options
        self.globalRequestOptions = [SMRequestOptions options];
        
        /// Add observer for set cache policy
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SM_didReceiveSetCachePolicyNotification:) name:SMSetCachePolicyNotification object:self.session.networkMonitor];
        
        // Add observer for dirty queue
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SM_didReceiveDirtyQueueNotification:) name:SMDirtyQueueNotification object:nil];
        
    }
    
    return self;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator == nil) {
        [NSPersistentStoreCoordinator registerStoreClass:[SMIncrementalStore class] forStoreType:SMIncrementalStoreType];
        
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSError *error = nil;
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, self, SM_DataStoreKey, nil];
        [_persistentStoreCoordinator addPersistentStoreWithType:SMIncrementalStoreType
                                                  configuration:nil
                                                            URL:nil
                                                        options:options
                                                          error:&error];
        if (error != nil) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating incremental persistent store: %@", error];
        }
        
    }
    
    return _persistentStoreCoordinator;
    
}

- (NSManagedObjectContext *)privateContext
{
    if (_privateContext == nil) {
        _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_privateContext setMergePolicy:self.defaultCoreDataMergePolicy];
        [_privateContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _privateContext;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectContext *)mainThreadContext
{
    if (_mainThreadContext == nil) {
        _mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainThreadContext setMergePolicy:self.defaultCoreDataMergePolicy];
        [_mainThreadContext setParentContext:self.privateContext];
        [_mainThreadContext setContextShouldObtainPermanentIDsBeforeSaving:YES];
    }
    return _mainThreadContext;
}

- (NSManagedObjectContext *)SM_newPrivateQueueContextWithParent:(NSManagedObjectContext *)parent
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setMergePolicy:self.defaultCoreDataMergePolicy];
    [context setParentContext:parent];
    [context setContextShouldObtainPermanentIDsBeforeSaving:YES];
    
    return context;
}

- (NSManagedObjectContext *)contextForCurrentThread
{
    if ([NSThread isMainThread])
	{
		return self.mainThreadContext;
	}
	else
	{
		NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
		NSManagedObjectContext *threadContext = [threadDict objectForKey:SM_ManagedObjectContextKey];
		if (threadContext == nil)
		{
			threadContext = [self SM_newPrivateQueueContextWithParent:self.mainThreadContext];
			[threadDict setObject:threadContext forKey:SM_ManagedObjectContextKey];
		}
		return threadContext;
	}
}

- (void)setDefaultMergePolicy:(id)mergePolicy applyToMainThreadContextAndParent:(BOOL)apply
{
    [self setDefaultCoreDataMergePolicy:mergePolicy applyToMainThreadContextAndParent:apply];
}

- (void)setDefaultCoreDataMergePolicy:(id)mergePolicy applyToMainThreadContextAndParent:(BOOL)apply
{
    if (mergePolicy != self.defaultCoreDataMergePolicy) {
        
        self.defaultCoreDataMergePolicy = mergePolicy;
        
        if (apply) {
            [self.mainThreadContext setMergePolicy:mergePolicy];
            [self.privateContext setMergePolicy:mergePolicy];
        }
    }
}

- (void)purgeCacheOfManagedObjectID:(NSManagedObjectID *)objectID
{
    dispatch_async(self.cachePurgeQueue, ^{
        NSDictionary *notificationUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:objectID, SMCachePurgeManagedObjectID, nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SMPurgeObjectFromCacheNotification object:self userInfo:notificationUserInfo];
    });
}

- (void)purgeCacheOfManagedObjects:(NSArray *)managedObjects
{
    NSMutableArray *arrayOfObjectIDs = [NSMutableArray arrayWithCapacity:[managedObjects count]];
    [managedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [arrayOfObjectIDs addObject:[obj objectID]];
    }];
    [self purgeCacheOfManagedObjectsIDs:arrayOfObjectIDs];
}

- (void)purgeCacheOfManagedObjectsIDs:(NSArray *)managedObjectIDs
{
    dispatch_async(self.cachePurgeQueue, ^{
        NSDictionary *notificationUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:managedObjectIDs, SMCachePurgeArrayOfManageObjectIDs, nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SMPurgeObjectsFromCacheNotification object:self userInfo:notificationUserInfo];
    });
}

- (void)purgeCacheOfObjectsWithEntityName:(NSString *)entityName
{
    dispatch_async(self.cachePurgeQueue, ^{
        NSDictionary *notificationUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:entityName, SMCachePurgeOfObjectsFromEntityName, nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SMPurgeObjectsFromCacheByEntityNotification object:self userInfo:notificationUserInfo];
    });
}

- (void)resetCache
{
    dispatch_async(self.cachePurgeQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SMResetCacheNotification object:self userInfo:nil];
    });
}

- (void)SM_didReceiveSetCachePolicyNotification:(NSNotification *)notification
{
    SMCachePolicy newCachePolicy = [[[notification userInfo] objectForKey:@"NewCachePolicy"] intValue];
    [self setCachePolicy:newCachePolicy];
}

- (void)SM_didReceiveDirtyQueueNotification:(NSNotification *)notification
{
    NSDictionary *dirtyQueue = [[notification userInfo] objectForKey:@"SMDirtyQueue"];
    if (dirtyQueue) {
        NSMutableArray *arrayOfDirtyObjects = [NSMutableArray array];
        [arrayOfDirtyObjects addObjectsFromArray:[dirtyQueue objectForKey:SMDirtyInsertedObjectKeys]];
        [arrayOfDirtyObjects addObjectsFromArray:[dirtyQueue objectForKey:SMDirtyUpdatedObjectKeys]];
        [arrayOfDirtyObjects addObjectsFromArray:[dirtyQueue objectForKey:SMDirtyDeletedObjectKeys]];
        self.currentDirtyQueue = [NSArray arrayWithArray:arrayOfDirtyObjects];
    }
}

- (void)syncWithServer
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SMSyncWithServerNotification object:self userInfo:nil];
}

- (BOOL)isDirtyObject:(NSManagedObjectID *)objectID
{
    if (self.currentDirtyQueue) {
        
        if ([self.currentDirtyQueue count] == 0) {
            return NO;
        }
        
        NSString *entityName = [[objectID entity] name];
        NSString *stringRepOfID = [[objectID URIRepresentation] absoluteString];
        NSArray *components = [stringRepOfID componentsSeparatedByString:[NSString stringWithFormat:@"%@/p", entityName]];
        if ([components count] != 2) {
            // Handle error
            [NSException raise:SMExceptionIncompatibleObject format:@"ObjectID in incorrect format."];
        }
        
        NSString *primaryKey = [components lastObject];
        
        NSArray *entry = [NSArray arrayWithObjects:primaryKey, entityName, nil];
        
        if ([self.currentDirtyQueue containsObject:entry]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)markFailedObjectAsSynced:(NSDictionary *)object purgeFromCache:(BOOL)purge
{
    NSManagedObjectID *objectID = [object objectForKey:SMFailedManagedObjectID];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMarkObjectAsSyncedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:objectID, @"ObjectID", [NSNumber numberWithBool:purge], @"Purge", nil]];
}

- (void)markArrayOfFailedObjectsAsSynced:(NSArray *)objects purgeFromCache:(BOOL)purge
{
    NSMutableArray *managedObjectIDs = [NSMutableArray arrayWithCapacity:[objects count]];
    [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [managedObjectIDs addObject:[obj objectForKey:SMFailedManagedObjectID]];
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:SMMarkArrayOfObjectsAsSyncedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithArray:managedObjectIDs], @"ObjectIDs", [NSNumber numberWithBool:purge], @"Purge", nil]];
}

- (void)setSyncCallbackForFailedInserts:(void (^)(NSArray *objects))block
{
    _syncCallbackForFailedInserts = block;
}

- (void)setSyncCallbackForFailedUpdates:(void (^)(NSArray *objects))block
{
    _syncCallbackForFailedUpdates = block;
}

- (void)setSyncCallbackForFailedDeletes:(void (^)(NSArray *objects))block
{
    _syncCallbackForFailedDeletes = block;
}

- (void)setSyncCompletionCallback:(void (^)(NSArray *objects))block
{
    _syncCompletionCallback = block;
}

@end


//
//  REMAppDelegate.h
//  iPunch
//
//  Created by Ronald Mannak on 7/12/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "iPunchIncrementalStore.h"

@interface REMAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;

@property (strong, nonatomic) UINavigationController *navigationController;

@end

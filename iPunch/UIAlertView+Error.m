//
//  UIAlertView+Error.m
//  BluetoothLETest
//
//  Created by Ronald Mannak on 2/14/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "UIAlertView+Error.h"

@implementation UIAlertView (Error)

+(UIAlertView*) displayError:(NSError*) error
{
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:[error localizedDescription]
                          message:[error localizedRecoverySuggestion]
                          delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                          otherButtonTitles:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        [alert show];
    });
    return alert;
}

@end

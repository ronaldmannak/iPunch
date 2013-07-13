//
//  UIAlertView+Error.h
//  BluetoothLETest
//
//  Created by Ronald Mannak on 2/14/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIAlertView (Error)
+(UIAlertView*) displayError:(NSError*) error;
@end

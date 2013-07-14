//
//  REMEditorViewController.m
//  iPunch
//
//  Created by Ronald Mannak on 7/14/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMEditorViewController.h"

@interface REMEditorViewController ()
@property (weak, nonatomic) IBOutlet UITextView *editor;
@property (weak, nonatomic) IBOutlet UIView *cardView;

@end

@implementation REMEditorViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)updatePunchedCard:(NSArray *)array
{
    
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSLog(@"TEST");
    return YES;
}

@end

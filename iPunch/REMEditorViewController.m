//
//  REMEditorViewController.m
//  iPunch
//
//  Created by Ronald Mannak on 7/14/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMEditorViewController.h"
#import "REMHollerithNumber.h"

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

- (void)updatePunchedCard
{
    NSString *text = [self.editor.text uppercaseString];
    NSMutableArray *hollerithRepresentation = [NSMutableArray arrayWithCapacity:80];
    for (int idx = 0; idx < text.length; idx++) {
        NSString *character = [NSString stringWithFormat:@"%C", [text characterAtIndex:idx]];
        REMHollerithNumber *number = [REMHollerithNumber HollerithWithString:character encoding:HollerithEncodingIBMModel029];
        [hollerithRepresentation addObject:number];
    }
    NSAssert([hollerithRepresentation count] == text.length, nil);
    
    // Add graphics
    [self.cardView.subviews makeObjectsPerformSelector:@selector(removeSubView:)];
    
    [hollerithRepresentation enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSArray *punchesArray = ((REMHollerithNumber *) obj).arrayValue;
        NSLog(@"H: %@", punchesArray);
//        for (NSString *punch in punchesArray)
    }];
}

- (void)removeSubView: (UIView *)view
{
    [view removeFromSuperview];
}
- (void)textViewDidChange:(UITextView *)textView
{
    [self updatePunchedCard];
}

@end

//
//  REMEditorViewController.m
//  iPunch
//
//  Created by Ronald Mannak on 7/14/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMEditorViewController.h"
#import "REMHollerithNumber.h"

#define LINE_HEIGHT 17.0f

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

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updatePunchedCard];
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
    [self.cardView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    __block CGFloat xPosition = 17.0f;
    UIImage *punchImage = [UIImage imageNamed:@"Punch.png"];
    
    [hollerithRepresentation enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSArray *punchesArray = ((REMHollerithNumber *) obj).arrayValue;
        NSLog(@"H: %@", punchesArray);
        
        CGFloat yPos = 3.0f + LINE_HEIGHT;
        for (NSString *punch in punchesArray) {
            if ([punch isEqualToString:@"X"]) {
                UIImageView *imageView = [[UIImageView alloc] initWithImage:punchImage];
                [self.cardView addSubview:imageView];
                CGPoint origin = CGPointMake(xPosition, yPos);
                CGRect frame = imageView.frame;
                frame.origin = origin;
                imageView.frame = frame;
            }
            yPos += LINE_HEIGHT;
        }
        xPosition += 6.0f;
        // Print *, "Hello World!"
    }];
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self updatePunchedCard];
}

@end

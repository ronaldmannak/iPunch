//
//  REMHollerithNumberIBMModel029Test.m
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMHollerithNumberIBMModel029Test.h"
#import "REMHollerithNumber.h"

@implementation REMHollerithNumberIBMModel029Test

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testClass
{
    id arrayInit = [REMHollerithNumber HollerithWithArray:@[@""] encoding:HollerithEncodingIBMModel029];
    STAssertEqualObjects([arrayInit class], [REMHollerithNumberIBMModel029 class], nil);
    
    id stringInit = [REMHollerithNumber HollerithWithString:@"" encoding:HollerithEncodingIBMModel029];
    STAssertEqualObjects([stringInit class], [REMHollerithNumberIBMModel029 class], nil);
}

- (void)testFromCardToReadableValue
{
    
//    REMHollerithNumber *number = [REMHollerithNumber HollerithWithArray:<#(NSArray *)#> encoding:<#(HollerithEncoding)#>]
}

- (void)testExample
{
//    STFail(@"Unit tests are not implemented yet in iPunchTests");
}


- (NSArray *)testStrings
{
    static NSArray *testStrings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testStrings = @[
                       @"REMHollerithNumberBCD",
                       @"REMHollerithNumberIBMModel026",
                       @"REMHollerithNumberIBMModel026Reporting",
                       @"REMHollerithNumberIBMModel026Fortran",
                       @"REMHollerithNumberIBMModel029",
                       @"REMHollerithNumberEBCDIC",
                       @"REMHollerithNumberDEC",
                       @"REMHollerithNumberGE",
                       @"REMHollerithNumberUNIVAC",
                       ];
    });
    return testStrings;
}

- (NSArray *)testArrays
{
    static NSArray *testArrays = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testArrays = @[
                        @"REMHollerithNumberBCD",
                        @"REMHollerithNumberIBMModel026",
                        @"REMHollerithNumberIBMModel026Reporting",
                        @"REMHollerithNumberIBMModel026Fortran",
                        @"REMHollerithNumberIBMModel029",
                        @"REMHollerithNumberEBCDIC",
                        @"REMHollerithNumberDEC",
                        @"REMHollerithNumberGE",
                        @"REMHollerithNumberUNIVAC",
                        ];
    });
    return testArrays;
}

@end

//
//  REMHollerithNumberIBMModel029Test.m
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMHollerithNumberIBMModel029Test.h"
#import "REMHollerithNumber.h"

@interface REMHollerithNumberIBMModel029Test ()
@property (nonatomic, strong) NSArray *testArrays;
@property (nonatomic, strong) NSArray *testStrings;
@end

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

- (void)testIndividualString
{
    REMHollerithNumber *number = [REMHollerithNumber HollerithWithString:@"A" encoding:HollerithEncodingIBMModel029];
    NSNumber *result = number.arrayValue[0];
    STAssertEqualObjects(result, @(1<<12|1<<1), nil);
    
    number = [REMHollerithNumber HollerithWithString:@"<" encoding:HollerithEncodingIBMModel029];
    result = number.arrayValue[0];
    STAssertEqualObjects(result, @(1<<12|1<<8|1<<4), nil);
}

- (void)testFromStringToCard
{
    STAssertTrue(self.testArrays.count == self.testStrings.count, nil);
    
    [self.testStrings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        REMHollerithNumber *number = [REMHollerithNumber HollerithWithString: obj encoding:HollerithEncodingIBMModel029];
        NSLog(@"number:%@", number.description);
        STAssertEqualObjects([number.arrayValue[0] class], [self.testArrays[idx] class], @"arrayValue: %@ testArray: %@", [number.arrayValue class], [self.testArrays[idx] class]);
        STAssertEqualObjects(number.arrayValue[0], self.testArrays[idx], @"Input: %@. Expected: %@ Received: %@", obj, self.testArrays[idx], number.arrayValue);
    }];    
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
                       @"&",
                       @"-",
                       @"1",
                       @"A",
                       @"C",
                       @"K",
                       @"S",
                       @"/",
                       @"<",
                       @"?",
                       @";",
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
                       @(1<<12),            // &
                       @(1<<11),            // -
                       @(1<<1),             // 1
                       @(1<<12|1<<1),       // A
                       @(1<<12|1<<3),       // C
                       @(1<<11|1<<2),       // K
                       @(1<<0|1<<2),        // S
                       @(1<<0|1<<1),        // /
                       @(1<<12|1<<4|1<<8),  // <
                       @(1<<0|1<<7|1<<8),   // ?
                       @(1<<11|1<<6|1<<8),  // ;
                        ];
    });
    return testArrays;
}

@end

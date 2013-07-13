//
//  REMHollerithNumber.m
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMHollerithNumber.h"

@interface REMHollerithNumber () {
    NSString *_stringValue;
    NSArray *_arrayValue;
}
@property (nonatomic) BOOL initializedWithString;
@property (nonatomic, strong) NSString  *stringValue;
@property (nonatomic, strong) NSArray   *arrayValue;

@end

@implementation REMHollerithNumber

+ (BOOL)isValidArray:(NSArray *)array
         forEncoding:(HollerithEncoding)encoding
{
    return NO;
}

+ (id)HollerithWithString:(NSString *)string
                 encoding:(HollerithEncoding)encoding
{
    NSArray *classNames = [self classNames];
    NSString *className = classNames[encoding];
    id hollerithClass = NSClassFromString(className);
    NSAssert(hollerithClass, @"Classname not found");
    
    REMHollerithNumber *hollerith = [[hollerithClass alloc] init];
    hollerith.stringValue = string;
    hollerith.encoding = encoding;
    hollerith.initializedWithString = YES;
    
    return hollerith;
}

+ (id)HollerithWithArray:(NSArray *)array
                 encoding:(HollerithEncoding)encoding
{
    NSArray *classNames = [self classNames];
    NSString *className = classNames[encoding];
    id hollerithClass = NSClassFromString(className);
    NSAssert(hollerithClass, @"Classname not found");
    
    REMHollerithNumber *hollerith = [[hollerithClass alloc] init];
    hollerith.arrayValue = array;
    hollerith.encoding = encoding;
    
    return hollerith;
}


+ (NSArray *)classNames
{
    static NSArray *classNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classNames = @[
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
    return classNames;
}


#pragma mark - Conversions

- (NSArray *)stringToArray:(NSString *)string
{
    NSAssert(NO, @"Override method in subclass");
    return nil;
}

- (NSString *)arrayToString:(NSArray *)array
{
    NSAssert(NO, @"Override method in subclass");
    return nil;
}


#pragma mark - Getters and Setters

- (void)setStringValue:(NSString *)stringValue
{
    NSAssert(_stringValue, @"_stringValue must be nil");
    _stringValue = stringValue;
    _arrayValue = [self stringToArray:stringValue];
    self.initializedWithString = YES;
}

- (void)setArrayValue:(NSArray *)arrayValue
{
    NSAssert(_stringValue == nil, @"_arrayValue must be nil");
    _arrayValue = arrayValue;
    _stringValue = [self arrayToString:arrayValue];
    self.initializedWithString = NO;
}

- (NSString *)stringValue
{
    if (_stringValue) {
        return _stringValue;
    } else {
        NSAssert(_arrayValue, @"_stringValue and _arrayValue can't be both nil");
        return [self arrayToString:self.arrayValue];
    }
}

- (NSArray *)arrayValue
{
    if (_arrayValue) {
        return _arrayValue;
    } else {
        NSAssert(_stringValue, @"_stringValue and _arrayValue can't be both nil");
        return [self stringToArray:self.stringValue];
    }
}

@end

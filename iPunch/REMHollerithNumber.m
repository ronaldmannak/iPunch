//
//  REMHollerithNumber.m
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMHollerithNumber.h"
#import <objc/message.h>

@interface REMHollerithNumber () {
    NSString *_stringValue;
    NSArray *_arrayValue;
}

@property (nonatomic, strong) NSDictionary  *hashTable;
@property (nonatomic, strong) NSString      *stringValue;
@property (nonatomic, strong) NSArray       *arrayValue;

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
    NSAssert(hollerithClass, @"Classname not found: %@", className);
    
    REMHollerithNumber *hollerith = [[hollerithClass alloc] init];
    hollerith.stringValue = string;
    hollerith.encoding = encoding;
    
    return hollerith;
}

+ (id)HollerithWithArray:(NSArray *)array
                 encoding:(HollerithEncoding)encoding
{
    NSArray *classNames = [self classNames];
    NSString *className = classNames[encoding];
    id hollerithClass = NSClassFromString(className);
    NSAssert(hollerithClass, @"Classname not found: %@", className);
    
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

#pragma mark - Description

- (NSString *)description
{
    const char *className = class_getName([self class]);
    return [NSString stringWithFormat:@"%s: %@", className, self.stringValue? : [self arrayToString:self.arrayValue]];
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
    NSAssert(_arrayValue == nil, @"_arrayValue must be nil");
    _stringValue = stringValue;
//    _arrayValue = [self stringToArray:stringValue];
}

- (void)setArrayValue:(NSArray *)arrayValue
{
    NSAssert(_stringValue == nil, @"_stringValue must be nil");
    _arrayValue = arrayValue;
//    _stringValue = [self arrayToString:arrayValue];
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

@implementation REMHollerithNumberIBMModel029

- (id)init
{
    self = [super init];
    if (self) {
        NSString *hashString = @"&-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ:#@'=\"¢.<(+|!$*);¬ ,%_>?";
        
        NSArray *hashValues = @[
            @(1<<12), @(1<<11), @(1<<0), @(1<<1), @(1<<2), @(1<<3), @(1<<4), @(1<<5), @(1<<6), @(1<<7), @(1<<8), @(1<<9),                          // &-0123456789
            @(1<<1|1<<12), @(1<<2|1<<12), @(1<<3|1<<12), @(1<<4|1<<12), @(1<<5|1<<12), @(1<<6|1<<12), @(1<<7|1<<12), @(1<<8|1<<12), @(1<<9|1<<12), // ABCDEFGHI
            @(1<<1|1<<11), @(1<<2|1<<11), @(1<<3|1<<11), @(1<<4|1<<11), @(1<<5|1<<11), @(1<<6|1<<11), @(1<<7|1<<11), @(1<<8|1<<11), @(1<<9|1<<11), // JKLMNOPQR
            @(1<<1|1<<0), @(1<<2|1<<0), @(1<<3|1<<0), @(1<<4|1<<0), @(1<<5|1<<0), @(1<<6|1<<0), @(1<<7|1<<0), @(1<<8|1<<0), @(1<<9|1<<0),          // /STUVWXYZ
            @(1<<2|1<<8), @(1<<3|1<<8), @(1<<4|1<<8), @(1<<5|1<<8), @(1<<6|1<<8), @(1<<7|1<<8),                                                    // b#@'>V
            @(1<<2|1<<8|1<<12), @(1<<3|1<<8|1<<12), @(1<<4|1<<8|1<<12), @(1<<5|1<<8|1<<12), @(1<<6|1<<8|1<<12), @(1<<7|1<<8|1<<12),                // ?.¤[<§
            @(1<<2|1<<8|1<<11), @(1<<3|1<<8|1<<11), @(1<<4|1<<8|1<<11), @(1<<5|1<<8|1<<11), @(1<<6|1<<8|1<<11), @(1<<7|1<<8|1<<11),                // !$*];^
            @(1<<2|1<<8|1<<11), @(1<<3|1<<8|1<<11), @(1<<4|1<<8|1<<11), @(1<<5|1<<8|1<<11), @(1<<6|1<<8|1<<11), @(1<<7|1<<8|1<<11),                // ±,%v\¶
                                ];
        
        NSAssert([hashValues count] == [hashString length], nil);
        [hashValues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *key = [NSString stringWithFormat:@"%c", [hashString characterAtIndex:idx]];
            [self.hashTable setValue:hashValues[idx] forKey:key];
        }];
    }
    return self;
}

#pragma mark - Conversions

- (NSArray *)stringToArray:(NSString *)string
{
    return nil;
}

- (NSString *)arrayToString:(NSArray *)array
{
    return nil;
}

@end

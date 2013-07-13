/*
 * Copyright 2012-2013 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "SMIncrementalStore+Query.h"
#import "NSEntityDescription+StackMobSerialization.h"
#import "SMError.h"
#import "SMPredicate.h"

@implementation SMIncrementalStore (Query)

- (SMQuery *)queryForEntity:(NSEntityDescription *)entityDescription
                  predicate:(NSPredicate *)predicate
                      error:(NSError *__autoreleasing *)error {
    
    SMQuery *query = [[SMQuery alloc] initWithEntity:entityDescription];
    [self buildQuery:&query forPredicate:predicate error:error];
    
    return query;
}

- (SMQuery *)queryForFetchRequest:(NSFetchRequest *)fetchRequest
                            error:(NSError *__autoreleasing *)error {
    
    SMQuery *query = [self queryForEntity:fetchRequest.entity
                                predicate:fetchRequest.predicate
                                    error:error];
    
    if (*error != nil) {
        *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
        return nil;
    }
    
    // Limit / pagination
    
    if (fetchRequest.fetchBatchSize) { // The default is 0, which means "everything"
        [self setError:error withReason:@"NSFetchRequest fetchBatchSize not supported"];
        return nil;
    }
    
    NSUInteger fetchOffset = fetchRequest.fetchOffset;
    NSUInteger fetchLimit = fetchRequest.fetchLimit;
    NSString *rangeHeader;
    
    if (fetchOffset) {
        if (fetchLimit) {
            rangeHeader = [NSString stringWithFormat:@"objects=%ld-%ld", (unsigned long)fetchOffset, (unsigned long)fetchOffset+fetchLimit];
        } else {
            rangeHeader = [NSString stringWithFormat:@"objects=%ld-", (unsigned long)fetchOffset];
        }
        [[query requestHeaders] setValue:rangeHeader forKey:@"Range"];
    }
    
    // Ordering
    
    [fetchRequest.sortDescriptors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *fieldName = nil;
        if ([[obj key] rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound) {
            fieldName = [self convertPredicateExpressionToStackMobFieldName:[obj key] entity:fetchRequest.entity];
        } else {
            fieldName = [obj key];
        }
        [query orderByField:fieldName ascending:[obj ascending]];
    }];
    
    return query;
}

- (NSString *)convertPredicateExpressionToStackMobFieldName:(NSString *)keyPath entity:(NSEntityDescription *)entity
{
    NSPropertyDescription *property = [[entity propertiesByName] objectForKey:keyPath];
    if (!property) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Property not found for predicate field %@ in entity %@", keyPath, entity];
    }
    return [entity SMFieldNameForProperty:property];
}

- (BOOL)setError:(NSError *__autoreleasing *)error withReason:(NSString *)reason {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:reason forKey:NSLocalizedDescriptionKey];
    if (error != NULL) {
        *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:userInfo];
        *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
    }
    
    return YES;
    
}

- (BOOL)buildBetweenQuery:(SMQuery *__autoreleasing *)query leftHandExpression:(id)lhs rightHandExpression:(id)rhs error:(NSError *__autoreleasing *)error
{
    if (![rhs isKindOfClass:[NSArray class]]) {
        [self setError:error withReason:@"RHS must be an NSArray"];
        return NO;
    }
    NSString *field = (NSString *)lhs;
    NSArray *range = (NSArray *)rhs;
    NSNumber *low = (NSNumber *)[range objectAtIndex:0];
    NSNumber *high = (NSNumber *)[range objectAtIndex:1];
    
    [*query where:field isGreaterThanOrEqualTo:low];
    [*query where:field isLessThanOrEqualTo:high];
    
    return YES;
}

- (BOOL)buildInQuery:(SMQuery *__autoreleasing *)query leftHandExpression:(id)lhs rightHandExpression:(id)rhs error:(NSError *__autoreleasing *)error
{
    if (![rhs isKindOfClass:[NSArray class]]) {
        [self setError:error withReason:@"RHS must be an NSArray"];
        return NO;
    }
    NSString *field = (NSString *)lhs;
    NSArray *arrayToSearch = (NSArray *)rhs;
    
    [*query where:field isIn:arrayToSearch];
    
    return YES;
}

- (BOOL)buildNotInQuery:(SMQuery *__autoreleasing *)query leftHandExpression:(id)lhs rightHandExpression:(id)rhs error:(NSError *__autoreleasing *)error
{
    if (![rhs isKindOfClass:[NSArray class]]) {
        [self setError:error withReason:@"RHS must be an NSArray"];
        return NO;
    }
    NSString *field = (NSString *)lhs;
    NSArray *arrayToSearch = (NSArray *)rhs;
    
    [*query where:field isNotIn:arrayToSearch];
    
    return YES;
}

- (BOOL)buildQuery:(SMQuery *__autoreleasing *)query forCompoundPredicate:(NSCompoundPredicate *)compoundPredicate error:(NSError *__autoreleasing *)error
{
    switch ([compoundPredicate compoundPredicateType]) {
        case NSNotPredicateType: {
            if ([[compoundPredicate subpredicates] count] != 1) {
                [self setError:error withReason:@"Predicate type not supported. Not predicates can only contain 1 subpredicate."];
                return NO;
            }
            
            NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)[[compoundPredicate subpredicates] lastObject];
            SMQuery *subQuery = [[SMQuery alloc] initWithEntity:[*query entity]];
            [self buildNotQuery:&subQuery forComparisonPredicate:comparisonPredicate error:error];
            [*query and:subQuery];
        }
            break;
        case NSAndPredicateType: {
            SMQuery *subQuery = [[SMQuery alloc] initWithEntity:[*query entity]];
            for (unsigned int i = 0; i < [[compoundPredicate subpredicates] count]; i++) {
                NSPredicate *subpredicate = [[compoundPredicate subpredicates] objectAtIndex:i];
                [self buildQuery:&subQuery forPredicate:subpredicate error:error];
            }
            [*query and:subQuery];
        }
            break;
        case NSOrPredicateType: {
            __block NSMutableArray *arrayOfQueries = [NSMutableArray array];
            for (unsigned int i = 0; i < [[compoundPredicate subpredicates] count]; i++) {
                SMQuery *subQuery = [[SMQuery alloc] initWithEntity:[*query entity]];
                NSPredicate *subpredicate = [[compoundPredicate subpredicates] objectAtIndex:i];
                [self buildQuery:&subQuery forPredicate:subpredicate error:error];
                [arrayOfQueries addObject:subQuery];
            }
            __block SMQuery *ORedQuery = [[SMQuery alloc] initWithEntity:[*query entity]];
            [arrayOfQueries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                ORedQuery = [ORedQuery or:obj];
            }];
            [*query and:ORedQuery];
        }
            break;
        default: {
            [self setError:error withReason:@"Predicate type not supported."];
            return NO;
        }
            break;
    }
    
    return YES;
}

- (BOOL)buildQuery:(SMQuery *__autoreleasing *)query forComparisonPredicate:(NSComparisonPredicate *)comparisonPredicate error:(NSError *__autoreleasing *)error
{
    if (comparisonPredicate.leftExpression.expressionType != NSKeyPathExpressionType) {
        [self setError:error withReason:@"LHS must be usable as a remote keypath"];
        return NO;
    } else if (comparisonPredicate.rightExpression.expressionType != NSConstantValueExpressionType) {
        [self setError:error withReason:@"RHS must be a constant-valued expression"];
        return NO;
    }
    
    // Convert leftExpression keyPath to SM equivalent field name if needed
    NSString *lhs = nil;
    if ([comparisonPredicate.leftExpression.keyPath rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound) {
        lhs = [self convertPredicateExpressionToStackMobFieldName:comparisonPredicate.leftExpression.keyPath entity:[*query entity]];
    } else {
        lhs = comparisonPredicate.leftExpression.keyPath;
    }
    
    id rhs = comparisonPredicate.rightExpression.constantValue;
    NSAttributeDescription *attributeDesc = [[[*query entity] attributesByName] objectForKey:comparisonPredicate.leftExpression.keyPath];
    switch (comparisonPredicate.predicateOperatorType) {
        case NSEqualToPredicateOperatorType:
            if (attributeDesc != nil && [attributeDesc attributeType] == NSBooleanAttributeType) {
                if (rhs == [NSNumber numberWithBool:YES]) {
                    rhs = @"true";
                } else if (rhs == [NSNumber numberWithBool:NO]) {
                    rhs = @"false";
                }
            } else if ([rhs isKindOfClass:[NSManagedObject class]]) {
                rhs = (NSString *)[self referenceObjectForObjectID:[rhs objectID]];;
            } else if ([rhs isKindOfClass:[NSManagedObjectID class]]) {
                rhs = (NSString *)[self referenceObjectForObjectID:rhs];
            }
            [*query where:lhs isEqualTo:rhs];
            break;
        case NSNotEqualToPredicateOperatorType:
            if (attributeDesc != nil && [attributeDesc attributeType] == NSBooleanAttributeType) {
                if (rhs == [NSNumber numberWithBool:YES]) {
                    rhs = @"true";
                } else if (rhs == [NSNumber numberWithBool:NO]) {
                    rhs = @"false";
                }
            } else if ([rhs isKindOfClass:[NSManagedObject class]]) {
                rhs = (NSString *)[self referenceObjectForObjectID:[rhs objectID]];;
            } else if ([rhs isKindOfClass:[NSManagedObjectID class]]) {
                rhs = (NSString *)[self referenceObjectForObjectID:rhs];
            }
            [*query where:lhs isNotEqualTo:rhs];
            break;
        case NSLessThanPredicateOperatorType:
            [*query where:lhs isLessThan:rhs];
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            [*query where:lhs isLessThanOrEqualTo:rhs];
            break;
        case NSGreaterThanPredicateOperatorType:
            [*query where:lhs isGreaterThan:rhs];
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            [*query where:lhs isGreaterThanOrEqualTo:rhs];
            break;
        case NSBetweenPredicateOperatorType:
            [self buildBetweenQuery:query leftHandExpression:lhs rightHandExpression:rhs error:error];
            break;
        case NSInPredicateOperatorType:
            [self buildInQuery:query leftHandExpression:lhs rightHandExpression:rhs error:error];
            break;
        default:
            [self setError:error withReason:@"Predicate type not supported."];
            break;
    }
    
    return YES;
}

- (BOOL)buildNotQuery:(SMQuery *__autoreleasing *)query forComparisonPredicate:(NSComparisonPredicate *)comparisonPredicate error:(NSError *__autoreleasing *)error
{
    if (comparisonPredicate.leftExpression.expressionType != NSKeyPathExpressionType) {
        [self setError:error withReason:@"LHS must be usable as a remote keypath"];
        return NO;
    } else if (comparisonPredicate.rightExpression.expressionType != NSConstantValueExpressionType) {
        [self setError:error withReason:@"RHS must be a constant-valued expression"];
        return NO;
    }
    
    // Convert leftExpression keyPath to SM equivalent field name if needed
    NSString *lhs = nil;
    if ([comparisonPredicate.leftExpression.keyPath rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound) {
        lhs = [self convertPredicateExpressionToStackMobFieldName:comparisonPredicate.leftExpression.keyPath entity:[*query entity]];
    } else {
        lhs = comparisonPredicate.leftExpression.keyPath;
    }
    
    id rhs = comparisonPredicate.rightExpression.constantValue;
    
    switch (comparisonPredicate.predicateOperatorType) {
        case NSInPredicateOperatorType:
            [self buildNotInQuery:query leftHandExpression:lhs rightHandExpression:rhs error:error];
            break;
        default:
            [self setError:error withReason:@"Predicate type not supported."];
            break;
    }
    
    return YES;
    
    
}

-(BOOL)buildQuery:(SMQuery *__autoreleasing *)query forSMPredicate:(SMPredicate *)predicate error:(NSError *__autoreleasing *)error
{
    switch (predicate.sm_predicateOperatorType) {
            
        case SMGeoQueryWithinMilesOperatorType:
            [self buildGeoQueryMiles:query forSMPredicate:predicate error:error];
            break;
        case SMGeoQueryWithinKilometersOperatorType:
            [self buildGeoQueryKilometers:query forSMPredicate:predicate error:error];
            break;
        case SMGeoQueryWithinBoundsOperatorType:
            [self buildGeoQueryBounds:query forSMPredicate:predicate error:error];
            break;
        case SMGeoQueryNearOperatorType:
            [self buildGeoQueryNear:query forSMPredicate:predicate error:error];
            break;
        default:
            [self setError:error withReason:@"Predicate type not supported."];
            break;
    }
    
    
    return YES;
}

-(BOOL)buildGeoQueryMiles:(SMQuery *__autoreleasing *)query forSMPredicate:(SMPredicate *)predicate error:(NSError *__autoreleasing *)error
{
    NSDictionary *geoDictionary = [NSDictionary dictionaryWithDictionary:predicate.predicateDictionary];
    
    NSDictionary *coordinate = [geoDictionary objectForKey:GEOQUERY_COORDINATE];
    NSNumber *latitude = [coordinate objectForKey:GEOQUERY_LAT];
    NSNumber *longitude = [coordinate objectForKey:GEOQUERY_LONG];
    
    CLLocationCoordinate2D point;
    point.latitude = [latitude doubleValue];
    point.longitude = [longitude doubleValue];
    
    NSNumber *distance = [geoDictionary objectForKey:GEOQUERY_MILES];
    CLLocationDistance miles = [distance doubleValue];
    
    NSString *field = [geoDictionary objectForKey:GEOQUERY_FIELD];
    
    [*query where:field isWithin:miles milesOf:point];
    
    return YES; 
}

-(BOOL)buildGeoQueryKilometers:(SMQuery *__autoreleasing *)query forSMPredicate:(SMPredicate *)predicate error:(NSError *__autoreleasing *)error
{
    NSDictionary *geoDictionary = [NSDictionary dictionaryWithDictionary:predicate.predicateDictionary];
    
    NSDictionary *coordinate = [geoDictionary objectForKey:GEOQUERY_COORDINATE];
    NSNumber *latitude = [coordinate objectForKey:GEOQUERY_LAT];
    NSNumber *longitude = [coordinate objectForKey:GEOQUERY_LONG];
    
    CLLocationCoordinate2D point;
    point.latitude = [latitude doubleValue];
    point.longitude = [longitude doubleValue];
    
    NSNumber *distance = [geoDictionary objectForKey:GEOQUERY_KILOMETERS];
    CLLocationDistance kilometers = [distance doubleValue];
    
    NSString *field = [geoDictionary objectForKey:GEOQUERY_FIELD];
    
    [*query where:field isWithin:kilometers kilometersOf:point];
    
    return YES; 
}

-(BOOL)buildGeoQueryBounds:(SMQuery *__autoreleasing *)query forSMPredicate:(SMPredicate *)predicate error:(NSError *__autoreleasing *)error
{
    NSDictionary *geoDictionary = [NSDictionary dictionaryWithDictionary:predicate.predicateDictionary];
    
    NSDictionary *swCoordinate = [geoDictionary objectForKey:GEOQUERY_SW_BOUND];
    NSNumber *swLatitude = [swCoordinate objectForKey:GEOQUERY_LAT];
    NSNumber *swLongitude = [swCoordinate objectForKey:GEOQUERY_LONG];
    
    CLLocationCoordinate2D swPoint;
    swPoint.latitude = [swLatitude doubleValue];
    swPoint.longitude = [swLongitude doubleValue];
    
    
    NSDictionary *neCoordinate = [geoDictionary objectForKey:GEOQUERY_NE_BOUND];
    NSNumber *neLatitude = [neCoordinate objectForKey:GEOQUERY_LAT];
    NSNumber *neLongitude = [neCoordinate objectForKey:GEOQUERY_LONG];
    
    CLLocationCoordinate2D nePoint;
    nePoint.latitude = [neLatitude doubleValue];
    nePoint.longitude = [neLongitude doubleValue];
    
    NSString *field = [geoDictionary objectForKey:GEOQUERY_FIELD];
    
    [*query where:field isWithinBoundsWithSWCorner:swPoint andNECorner:nePoint];
    
    
    return YES;
}

-(BOOL)buildGeoQueryNear:(SMQuery *__autoreleasing *)query forSMPredicate:(SMPredicate *)predicate error:(NSError *__autoreleasing *)error
{
    NSDictionary *geoDictionary = [NSDictionary dictionaryWithDictionary:predicate.predicateDictionary];
    
    NSDictionary *coordinate = [geoDictionary objectForKey:GEOQUERY_COORDINATE];
    NSNumber *latitude = [coordinate objectForKey:GEOQUERY_LAT];
    NSNumber *longitude = [coordinate objectForKey:GEOQUERY_LONG];
    
    CLLocationCoordinate2D point;
    point.latitude = [latitude doubleValue];
    point.longitude = [longitude doubleValue];
    
    NSString *field = [geoDictionary objectForKey:GEOQUERY_FIELD];
    
    [*query where:field near:point];
    
    return YES;  
}


- (BOOL)buildQuery:(SMQuery *__autoreleasing *)query forPredicate:(NSPredicate *)predicate error:(NSError *__autoreleasing *)error
{
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        [self buildQuery:query forCompoundPredicate:(NSCompoundPredicate *)predicate error:error];
    }
    else if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        [self buildQuery:query forComparisonPredicate:(NSComparisonPredicate *)predicate error:error];
    }
    else if ([predicate isKindOfClass:[SMPredicate class]]) {
        [self buildQuery:query forSMPredicate:(SMPredicate *)predicate error:error];
    }
    
    return YES;
}


@end

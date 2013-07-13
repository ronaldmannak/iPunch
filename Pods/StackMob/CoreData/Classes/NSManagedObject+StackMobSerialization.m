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

#import "NSManagedObject+StackMobSerialization.h"
#import "SMError.h"
#import "SMUserManagedObject.h"
#import "SMError.h"
#import "NSEntityDescription+StackMobSerialization.h"

@implementation NSManagedObject (StackMobSerialization)

- (NSString *)SMSchema
{
    return [[self entity] SMSchema];
}

- (NSString *)SMObjectId
{
    NSString *objectIdField = [self primaryKeyField];
    if ([[[self entity] attributesByName] objectForKey:objectIdField] == nil) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Unable to locate a primary key field for %@, expected %@.  If this is an Entity which describes user objects, and your managed object subclass inherits from SMUserManagedObject, make sure to include an attribute that matches the value returned by your SMClient's userPrimaryKeyField property.", [self description], objectIdField];
    }
    return [self valueForKey:objectIdField];
}

- (NSString *)assignObjectId
{
    id objectId = nil;
    CFUUIDRef uuid = CFUUIDCreate(CFAllocatorGetDefault());
    objectId = (__bridge_transfer NSString *)CFUUIDCreateString(CFAllocatorGetDefault(), uuid);
    [self setValue:objectId forKey:[self primaryKeyField]];
    CFRelease(uuid);
    return objectId;
}

- (NSString *)primaryKeyField
{
    NSString *objectIdField = nil;
    
    // Search for schemanameId
    objectIdField = [[self SMSchema] stringByAppendingFormat:@"Id"];
    if ([[[self entity] propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Search for schemaname_id
    objectIdField = [[self SMSchema] stringByAppendingFormat:@"_id"];
    if ([[[self entity] propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Raise an exception and return nil
    [NSException raise:SMExceptionIncompatibleObject format:@"No Attribute found for entity %@ which maps to the primary key on StackMob. The Attribute name should match one of the following formats: lowercasedEntityNameId or lowercasedEntityName_id.  If the managed object subclass for %@ inherits from SMUserManagedObject, meaning it is intended to define user objects, you may return either of the above formats or whatever lowercase string with optional underscores matches the primary key field on StackMob.", [[self entity] name], [[self entity] name]];
    return nil;
}

- (NSString *)SMPrimaryKeyField
{
    return [[self entity] SMFieldNameForProperty:[[[self entity] propertiesByName] objectForKey:[self primaryKeyField]]];
}

- (NSDictionary *)SMDictionarySerialization:(BOOL)serializeFullObjects sendLocalTimestamps:(BOOL)sendLocalTimestamps
{
    NSMutableArray *arrayOfRelationshipHeaders = [NSMutableArray array];
    NSMutableDictionary *contentsOfSerializedObject = [NSMutableDictionary dictionaryWithObject:[self SMDictionarySerializationByTraversingRelationshipsExcludingObjects:nil entities:nil relationshipHeaderValues:&arrayOfRelationshipHeaders relationshipKeyPath:nil serializeFullObjects:serializeFullObjects sendLocalTimestamps:sendLocalTimestamps] forKey:@"SerializedDict"];
    
    if ([arrayOfRelationshipHeaders count] > 0) {
        
        // add array joined by & to contentsDict
        [contentsOfSerializedObject setObject:[arrayOfRelationshipHeaders componentsJoinedByString:@"&"] forKey:@"X-StackMob-Relations"];
    }
    
    return contentsOfSerializedObject;
    
}

- (NSDictionary *)SMDictionarySerializationByTraversingRelationshipsExcludingObjects:(NSMutableSet *)processedObjects entities:(NSMutableSet *)processedEntities relationshipHeaderValues:(NSMutableArray *__autoreleasing *)values relationshipKeyPath:(NSString *)keyPath serializeFullObjects:(BOOL)serializeFullObjects sendLocalTimestamps:(BOOL)sendLocalTimestamps
{
    if (processedObjects == nil) {
        processedObjects = [NSMutableSet set];
    }
    if (processedEntities == nil) {
        processedEntities = [NSMutableSet set];
    }
    
    [processedObjects addObject:self];
    
    NSEntityDescription *selfEntity = [self entity];
    
    NSMutableDictionary *objectDictionary = [NSMutableDictionary dictionary];
    
    NSDictionary *valuesToSerialize = serializeFullObjects ? [self dictionaryWithValuesForKeys:[[selfEntity propertiesByName] allKeys]] : self.changedValues;
    
    NSMutableArray *attributesToCheckForDefaultValues = !serializeFullObjects && [self isInserted] ? [[[selfEntity attributesByName] allKeys] mutableCopy] : nil;
    
    [valuesToSerialize enumerateKeysAndObjectsUsingBlock:^(id propertyKey, id propertyValue, BOOL *stop) {
        
        NSPropertyDescription *property = [[selfEntity propertiesByName] objectForKey:propertyKey];
        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *attributeDescription = (NSAttributeDescription *)property;
            NSString *fieldName = [selfEntity SMFieldNameForProperty:property];
            if (attributeDescription.attributeType != NSUndefinedAttributeType && propertyValue != nil && propertyValue != [NSNull null]) {
                if (attributeDescription.attributeType == NSDateAttributeType) {
                    
                    NSDate *dateValue = propertyValue;
                    long double convertedDate = (long double)[dateValue timeIntervalSince1970] * 1000.0000;
                    NSNumber *numberToSet = [NSNumber numberWithUnsignedLongLong:convertedDate];
                    [objectDictionary setObject:numberToSet forKey:fieldName];
                    
                } else if (attributeDescription.attributeType == NSBooleanAttributeType) {
                    // make sure that boolean values are serialized as true or false
                    id value = propertyValue;
                    if ([value boolValue]) {
                        [objectDictionary setObject:[NSNumber numberWithBool:YES] forKey:fieldName];
                    }
                    else {
                        [objectDictionary setObject:[NSNumber numberWithBool:NO] forKey:fieldName];
                    }
                }  else if (attributeDescription.attributeType == NSTransformableAttributeType) {
                    
                    // make sure geopoint values are serialized as dictionaries
                    NSData *data = propertyValue;
                    NSDictionary *geoDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                    [objectDictionary setObject:geoDictionary forKey:fieldName];
                    
                } else {
                    id value = propertyValue;
                    [objectDictionary setObject:value forKey:fieldName];
                }
            }
            
            // Remove from attributes to check for default values
            if (attributesToCheckForDefaultValues) {
                [attributesToCheckForDefaultValues removeObject:propertyKey];
            }
        }
        else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
            if ([relationship isToMany]) {
                NSMutableArray *relatedObjectDictionaries = [NSMutableArray array];
                [(NSSet *)propertyValue enumerateObjectsUsingBlock:^(id child, BOOL *stopRelEnum) {
                    NSManagedObjectID *childManagedObjectID = [child objectID];
                    NSString *entityName = [[child entity] name];
                    NSArray *components = [[[childManagedObjectID URIRepresentation] absoluteString] componentsSeparatedByString:[NSString stringWithFormat:@"%@/p", entityName]];
                    NSString *childObjectID = [components objectAtIndex:1];
                    
                    [relatedObjectDictionaries addObject:childObjectID];
                }];
                
                // add relationship header only if there are actual keys
                if ([relatedObjectDictionaries count] > 0) {
                    NSMutableString *relationshipKeyPath = [NSMutableString string];
                    if (keyPath && [keyPath length] > 0) {
                        [relationshipKeyPath appendFormat:@"%@.", keyPath];
                    }
                    [relationshipKeyPath appendString:[selfEntity SMFieldNameForProperty:relationship]];
                    
                    [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] SMSchema]]];
                }
                [objectDictionary setObject:relatedObjectDictionaries forKey:[selfEntity SMFieldNameForProperty:property]];
            } else {
                if (propertyValue == [NSNull null]) {
                    [objectDictionary setObject:propertyValue forKey:[selfEntity SMFieldNameForProperty:property]];
                }
                else if ([processedObjects containsObject:propertyValue]) {
                    // add relationship header
                    NSMutableString *relationshipKeyPath = [NSMutableString string];
                    if (keyPath && [keyPath length] > 0) {
                        [relationshipKeyPath appendFormat:@"%@.", keyPath];
                    }
                    [relationshipKeyPath appendString:[selfEntity SMFieldNameForProperty:relationship]];
                    
                    [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] SMSchema]]];
                    
                    NSPropertyDescription *primaryKeyProperty = [[[relationship destinationEntity] propertiesByName] objectForKey:[propertyValue primaryKeyField]];
                    [objectDictionary setObject:[NSDictionary dictionaryWithObject:[propertyValue SMObjectId] forKey:[[relationship destinationEntity] SMFieldNameForProperty:primaryKeyProperty]] forKey:[selfEntity SMFieldNameForProperty:property]];
                }
                else {
                    NSMutableString *relationshipKeyPath = [NSMutableString string];
                    if (keyPath && [keyPath length] > 0) {
                        [relationshipKeyPath appendFormat:@"%@.", keyPath];
                    }
                    [relationshipKeyPath appendString:[selfEntity SMFieldNameForProperty:relationship]];
                    
                    [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] SMSchema]]];
                    
                    [objectDictionary setObject:[propertyValue SMDictionarySerializationByTraversingRelationshipsExcludingObjects:processedObjects entities:processedEntities relationshipHeaderValues:values relationshipKeyPath:relationshipKeyPath serializeFullObjects:serializeFullObjects sendLocalTimestamps:sendLocalTimestamps] forKey:[selfEntity SMFieldNameForProperty:property]];
                }
            }
        }
    }];
    
    // Check for default values
    if (attributesToCheckForDefaultValues && [attributesToCheckForDefaultValues count] > 0) {
        [attributesToCheckForDefaultValues enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
            NSAttributeDescription *attribute = [[selfEntity attributesByName] objectForKey:key];
            if ([attribute defaultValue]) {
                NSPropertyDescription *property = [[selfEntity propertiesByName] objectForKey:key];
                
                if (attribute.attributeType == NSBooleanAttributeType) {
                    NSNumber *boolNumber = [[attribute defaultValue] boolValue] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];
                    [objectDictionary setObject:boolNumber forKey:[selfEntity SMFieldNameForProperty:property]];
                } else {
                    [objectDictionary setObject:[attribute defaultValue] forKey:[selfEntity SMFieldNameForProperty:property]];
                }
            }
        }];
    }
    
    // Add value for primary key field if needed
    NSString *primaryKeyField = [self SMPrimaryKeyField];
    if (![objectDictionary valueForKey:primaryKeyField]) {
        [self attachObjectIdToDictionary:&objectDictionary];
    }
    
    if (serializeFullObjects && !sendLocalTimestamps) {
        // Remove any instances of createddate or lastmoddate
        [objectDictionary removeObjectForKey:@"createddate"];
        [objectDictionary removeObjectForKey:@"lastmoddate"];
    }
    
    if ([[objectDictionary allKeys] indexOfObject:@"sm_owner"] != NSNotFound && [objectDictionary objectForKey:@"sm_owner"] == [NSNull null]) {
        [objectDictionary removeObjectForKey:@"sm_owner"];
    }
    
    return objectDictionary;
}

- (void)attachObjectIdToDictionary:(NSDictionary **)objectDictionary
{
    NSMutableDictionary *dictionaryToReturn = [*objectDictionary mutableCopy];
    
    [dictionaryToReturn setObject:[self SMObjectId] forKey:[self SMPrimaryKeyField]];
    
    *objectDictionary = dictionaryToReturn;
}

- (id)valueForRelationshipKey:(NSString *)key error:(NSError *__autoreleasing*)error
{
    id result = nil;
    @try {
        result = [self valueForKey:key];
    }
    @catch (NSException *exception) {
        if ([exception name] == SMExceptionCannotFillRelationshipFault && NULL != error) {
            *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorCouldNotFillRelationshipFault userInfo:[NSDictionary dictionaryWithObject:[exception reason] forKey:NSLocalizedDescriptionKey]];
        }
            
            return nil;
    }
    
    return result;
    
}

@end

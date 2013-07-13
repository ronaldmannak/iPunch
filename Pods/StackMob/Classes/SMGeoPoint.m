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

#import "SMGeoPoint.h"
#import "SMError.h"
#import "SMLocationManager.h"

#define LATITUDE @"lat"
#define LONGITUDE @"lon"

@implementation NSDictionary (GeoPoint)

- (NSNumber *)latitude {
    return [self objectForKey:@"lat"];
}
- (NSNumber *)longitude {
   return [self objectForKey:@"lon"];
}

@end

@implementation SMGeoPoint

- (id)init {
    
    self = [super init];
    if (self) {

    }
    
    return self;
}

+ (SMGeoPoint *)geoPointWithLatitude:(NSNumber *)latitude longitude:(NSNumber *)longitude {
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:latitude,LATITUDE,longitude,LONGITUDE,nil];
    
    return (SMGeoPoint *)dictionary;
}

+ (SMGeoPoint *)geoPointWithCoordinate:(CLLocationCoordinate2D)coordinate {
    
    NSNumber *latitude = [NSNumber numberWithDouble:coordinate.latitude];
    NSNumber *longitude = [NSNumber numberWithDouble:coordinate.longitude];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:latitude,LATITUDE,longitude,LONGITUDE,nil];
    
    return (SMGeoPoint *)dictionary;
}

+ (void)getGeoPointForCurrentLocationOnSuccess:(SMGeoPointSuccessBlock)successBlock
                                     onFailure:(SMFailureBlock) failureBlock {
    
    [self getGeoPointForCurrentLocationWithOptions:[SMRequestOptions options] onSuccess:successBlock onFailure:failureBlock];
}

+ (void)getGeoPointForCurrentLocationWithOptions:(SMRequestOptions *)options
                                      onSuccess:(SMGeoPointSuccessBlock)successBlock
                                      onFailure:(SMFailureBlock)failureBlock {
    
    [self getGeoPointForCurrentLocationWithOptions:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

+ (void)getGeoPointForCurrentLocationWithOptions:(SMRequestOptions *)options
                            successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                            failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                       onSuccess:(SMGeoPointSuccessBlock)successBlock
                                       onFailure:(SMFailureBlock)failureBlock {
    
    // Start updating location
    [[[SMLocationManager sharedInstance] locationManager] startUpdatingLocation];
    
    // Get the current longitude and latitude
    NSNumber *latitude = [[NSNumber alloc] initWithDouble:[[[[SMLocationManager sharedInstance] locationManager] location] coordinate].latitude];
    NSNumber *longitude = [[NSNumber alloc] initWithDouble:[[[[SMLocationManager sharedInstance] locationManager] location] coordinate].longitude];
    
    if (![latitude doubleValue] || ![longitude doubleValue]) {
        if (options.numberOfRetries > 0) {
            [options setNumberOfRetries:(options.numberOfRetries - 1)];
            double delayInSeconds = 1.5;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self getGeoPointForCurrentLocationWithOptions:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
            });
        }
        else {
            [[[SMLocationManager sharedInstance] locationManager] stopUpdatingLocation];
            if ([SMLocationManager sharedInstance].locationManagerError != nil) {
                dispatch_async(failureCallbackQueue, ^{
                    NSError *error = [[SMLocationManager sharedInstance].locationManagerError copy];
                    failureBlock(error);
                    [SMLocationManager sharedInstance].locationManagerError = nil;
                });
            }
            else {
                dispatch_async(failureCallbackQueue, ^{
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"SMLocationManager failed to retrieve lat/lon after 3 attempts", nil) forKey:NSLocalizedDescriptionKey];
                    NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorLocationManagerFailed userInfo:userInfo];
                    failureBlock(error);
                });
            }
        }
        
    }
    else {
        [[[SMLocationManager sharedInstance] locationManager] stopUpdatingLocation];
        dispatch_async(successCallbackQueue, ^{
            SMGeoPoint *geoPoint = [SMGeoPoint geoPointWithLatitude:latitude longitude:longitude];
            successBlock(geoPoint);
        });
    }
}


@end

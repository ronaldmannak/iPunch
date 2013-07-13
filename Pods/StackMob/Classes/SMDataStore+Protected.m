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

#import "SMDataStore+Protected.h"
#import "SMError.h"
#import "SMJSONRequestOperation.h"
#import "SMRequestOptions.h"
#import "SMNetworkReachability.h"
#import "SMCustomCodeRequest.h"
#import "AFHTTPRequestOperation.h"
#import "AFHTTPRequestOperation+RemoveContentType.h"

#define SM_VENDOR_SPECIFIC_JSON @"application/vnd.stackmob+json"
#define SM_JSON @"application/json"
#define SM_TEXT_PLAIN @"text/plain"
#define SM_OCTET_STREAM @"application/octet-stream"

@implementation SMDataStore (SpecialCondition)

- (NSError *)errorFromResponse:(NSHTTPURLResponse *)response JSON:(id)JSON
{
    return [NSError errorWithDomain:HTTPErrorDomain code:response.statusCode userInfo:JSON];
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForSchema:(NSString *)schema withSuccessBlock:(SMDataStoreSuccessBlock)successBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(JSON, schema);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForObjectId:(NSString *)theObjectId ofSchema:(NSString *)schema withSuccessBlock:(SMDataStoreObjectIdSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(theObjectId, schema);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForSuccessBlock:(SMSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock();
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForResultSuccessBlock:(SMResultSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(JSON);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForResultsSuccessBlock:(SMResultsSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(JSON);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForQuerySuccessBlock:(SMResultsSuccessBlock)successBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock((NSArray *)JSON);
        }
    };
}


- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForObject:(NSDictionary *)theObject ofSchema:(NSString *)schema withFailureBlock:(SMDataStoreFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(error, theObject, schema) : failureBlock([self errorFromResponse:response JSON:JSON], theObject, schema);
        }
    };
}

- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForObjectId:(NSString *)theObjectId ofSchema:(NSString *)schema withFailureBlock:(SMDataStoreObjectIdFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(error, theObjectId, schema) : failureBlock([self errorFromResponse:response JSON:JSON], theObjectId, schema);
        }
    };
}

- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForFailureBlock:(SMFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(error) : failureBlock([self errorFromResponse:response JSON:JSON]);
        }
    };
}

- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForObject:(NSDictionary *)theObject options:(SMRequestOptions *)options originalSuccessBlock:(SMResultSuccessBlock)originalSuccessBlock coreDataSaveFailureBlock:(SMCoreDataSaveFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(request, error, theObject, options, originalSuccessBlock) : failureBlock(request, [self errorFromResponse:response JSON:JSON], theObject, options, originalSuccessBlock);
        }
    };
}

- (int)countFromRangeHeader:(NSString *)rangeHeader results:(NSArray *)results
{
    if (rangeHeader == nil) {
        //No range header means we've got all the results right here (1 or 0)
        return (int)[results count];
    } else {
        NSArray* parts = [rangeHeader componentsSeparatedByString: @"/"];
        if ([parts count] != 2) return -1;
        NSString *lastPart = [parts objectAtIndex: 1];
        if ([lastPart isEqualToString:@"*"]) return -2;
        if ([lastPart isEqualToString:@"0"]) return 0;
        int count = [lastPart intValue];
        if (count == 0) return -1; //real zero was filtered out above
        return count;
    } 
}

- (void)readObjectWithId:(NSString *)theObjectId inSchema:(NSString *)schema parameters:(NSDictionary *)parameters options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMDataStoreSuccessBlock)successBlock onFailure:(SMDataStoreObjectIdFailureBlock)failureBlock
{
    if (theObjectId == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error, theObjectId, schema);
        }
    } else {
        NSString *path = [[schema lowercaseString] stringByAppendingPathComponent:[self URLEncodedStringFromValue:theObjectId]];
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"GET" path:path parameters:parameters];
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForSchema:schema withSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObjectId:theObjectId ofSchema:schema withFailureBlock:failureBlock];
        [self queueRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}

- (void)refreshAndRetry:(NSURLRequest *)request originalError:(NSError *)originalError requestSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue requestFailureCallbackQueue:(dispatch_queue_t)failureCallbackQueue options:(SMRequestOptions *)options onSuccess:(SMFullResponseSuccessBlock)successBlock onFailure:(SMFullResponseFailureBlock)failureBlock
{
    if (self.session.refreshing) {
        if (failureBlock) {
            dispatch_async(failureCallbackQueue, ^{
                NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenInProgress userInfo:nil];
                failureBlock(request, nil, error, nil);
            });
        }
    } else {
        [options setTryRefreshToken:NO];
        __block dispatch_queue_t newQueueForRefresh = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        [self.session refreshTokenWithSuccessCallbackQueue:newQueueForRefresh failureCallbackQueue:newQueueForRefresh onSuccess:^(NSDictionary *userObject) {
            [self queueRequest:[self.session signRequest:request] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
         
        } onFailure:^(NSError *theError) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:theError, SMRefreshErrorObjectKey, @"Attempt to refresh access token failed.", NSLocalizedDescriptionKey, nil];
            if (originalError) {
                [userInfo setObject:originalError forKey:SMOriginalErrorCausingRefreshKey];
            }
            __block NSError *refreshError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenFailed userInfo:userInfo];
            if (self.session.tokenRefreshFailureBlock) {
                dispatch_async(failureCallbackQueue, ^{
                    SMFailureBlock newFailureBlock = ^(NSError *error){
                        failureBlock(nil, nil, error, nil);
                    };
                    self.session.tokenRefreshFailureBlock(refreshError, newFailureBlock);
                });
            } else if (failureBlock) {
                dispatch_async(failureCallbackQueue, ^{
                    failureBlock(request, nil, refreshError, nil);
                });
            }
        }];
    }
}

- (void)refreshAndRetryCustomCode:(NSURLRequest *)request customCodeRequestInstance:(SMCustomCodeRequest *)customCodeRequest originalError:(NSError *)originalError requestSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue requestFailureCallbackQueue:(dispatch_queue_t)failureCallbackQueue options:(SMRequestOptions *)options onSuccess:(SMFullResponseSuccessBlock)successBlock onFailure:(SMFullResponseFailureBlock)failureBlock
{
    if (self.session.refreshing) {
        if (failureBlock) {
            dispatch_async(failureCallbackQueue, ^{
                NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenInProgress userInfo:nil];
                failureBlock(request, nil, error, nil);
            });
        }
    } else {
        [options setTryRefreshToken:NO];
        __block dispatch_queue_t newQueueForRefresh = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        [self.session refreshTokenWithSuccessCallbackQueue:newQueueForRefresh failureCallbackQueue:newQueueForRefresh onSuccess:^(NSDictionary *userObject) {
            [self queueCustomCodeRequest:[self.session signRequest:request] customCodeRequestInstance:customCodeRequest options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
            
        } onFailure:^(NSError *theError) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:theError, SMRefreshErrorObjectKey, @"Attempt to refresh access token failed.", NSLocalizedDescriptionKey, nil];
            if (originalError) {
                [userInfo setObject:originalError forKey:SMOriginalErrorCausingRefreshKey];
            }
            __block NSError *refreshError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenFailed userInfo:userInfo];
            if (self.session.tokenRefreshFailureBlock) {
                dispatch_async(failureCallbackQueue, ^{
                    SMFailureBlock newFailureBlock = ^(NSError *error){
                        failureBlock(nil, nil, error, nil);
                    };
                    self.session.tokenRefreshFailureBlock(refreshError, newFailureBlock);
                });
            } else if (failureBlock) {
                dispatch_async(failureCallbackQueue, ^{
                    failureBlock(request, nil, refreshError, nil);
                });
            }
        }];
    }
}

- (AFJSONRequestOperation *)newOperationForRequest:(NSURLRequest *)request options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMFullResponseSuccessBlock)successBlock onFailure:(SMFullResponseFailureBlock)failureBlock
{
    if (options.headers && [options.headers count] > 0) {
        // Enumerate through options and add them to the request header.
        NSMutableURLRequest *tempRequest = [request mutableCopy];
        [options.headers enumerateKeysAndObjectsUsingBlock:^(id headerField, id headerValue, BOOL *stop) {
            [tempRequest setValue:headerValue forHTTPHeaderField:headerField];
        }];
        request = tempRequest;
        
        // Set the headers dictionary to empty, to prevent unnecessary enumeration during recursion.
        options.headers = [NSDictionary dictionary];
    }
    
    SMFullResponseFailureBlock retryBlock = ^(NSURLRequest *originalRequest, NSHTTPURLResponse *response, NSError *error, id JSON) {
        if ([response statusCode] == SMErrorServiceUnavailable && options.numberOfRetries > 0) {
            NSString *retryAfter = [[response allHeaderFields] valueForKey:@"Retry-After"];
            if (retryAfter) {
                [options setNumberOfRetries:(options.numberOfRetries - 1)];
                double delayInSeconds = [retryAfter doubleValue];
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    if (options.retryBlock) {
                        options.retryBlock(originalRequest, response, error, JSON, options, successBlock, failureBlock);
                    } else {
                        [self queueRequest:[self.session signRequest:originalRequest] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
                    }
                });
            } else {
                if (failureBlock) {
                    failureBlock(originalRequest, response, error, JSON);
                }
            }
        } else if ([error domain] == NSURLErrorDomain && [error code] == -1009) {
            if (failureBlock) {
                NSError *networkNotReachableError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[error userInfo]];
                failureBlock(originalRequest, response, networkNotReachableError, JSON);
            }
        } else {
            if (failureBlock) {
                failureBlock(originalRequest, response, error, JSON);
            }
        }
    };
    
    AFJSONRequestOperation *op = [SMJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:retryBlock];
    if (successCallbackQueue) {
        [op setSuccessCallbackQueue:successCallbackQueue];
    }
    if (failureCallbackQueue) {
        [op setFailureCallbackQueue:failureCallbackQueue];
    }
    
    return op;
    
}

- (void)queueRequest:(NSURLRequest *)request options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMFullResponseSuccessBlock)onSuccess onFailure:(SMFullResponseFailureBlock)onFailure
{
    if (options.headers && [options.headers count] > 0) {
        // Enumerate through options and add them to the request header.
        NSMutableURLRequest *tempRequest = [request mutableCopy];
        [options.headers enumerateKeysAndObjectsUsingBlock:^(id headerField, id headerValue, BOOL *stop) {
            
            // Error checks for functionality not supported
            if ([headerField isEqualToString:@"X-StackMob-Expand"]) {
                if ([[request HTTPMethod] isEqualToString:@"POST"] || [[request HTTPMethod] isEqualToString:@"PUT"]) {
                    [NSException raise:SMExceptionIncompatibleObject format:@"Expand depth is not supported for creates or updates.  Please check your requests and edit accordingly."];
                }
            }
            
            [tempRequest setValue:headerValue forHTTPHeaderField:headerField];
        }];
        request = tempRequest;
        
        // Set the headers dictionary to empty, to prevent unnecessary enumeration during recursion.
        options.headers = [NSDictionary dictionary];
    }
    
    
    
    if ([self.session eligibleForTokenRefresh:options]) {
        [self refreshAndRetry:request originalError:nil requestSuccessCallbackQueue:successCallbackQueue requestFailureCallbackQueue:failureCallbackQueue options:options onSuccess:onSuccess onFailure:onFailure];
    } 
    else {
        SMFullResponseFailureBlock retryBlock = ^(NSURLRequest *originalRequest, NSHTTPURLResponse *response, NSError *error, id JSON) {
            if ([response statusCode] == SMErrorUnauthorized && options.tryRefreshToken && self.session.refreshToken != nil) {
                [self refreshAndRetry:originalRequest originalError:[self errorFromResponse:response JSON:JSON] requestSuccessCallbackQueue:successCallbackQueue requestFailureCallbackQueue:failureCallbackQueue options:options onSuccess:onSuccess onFailure:onFailure];
            } else if ([response statusCode] == SMErrorServiceUnavailable && options.numberOfRetries > 0) {
                NSString *retryAfter = [[response allHeaderFields] valueForKey:@"Retry-After"];
                if (retryAfter) {
                    dispatch_queue_t retryQueue = dispatch_queue_create("com.stackmob.retry", NULL);
                    [options setNumberOfRetries:(options.numberOfRetries - 1)];
                    double delayInSeconds = [retryAfter doubleValue];
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                    dispatch_after(popTime, retryQueue, ^(void){
                        if (options.retryBlock) {
                            options.retryBlock(originalRequest, response, error, JSON, options, onSuccess, onFailure);
                        } else {
                            [self queueRequest:[self.session signRequest:originalRequest] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:onSuccess onFailure:onFailure];
                        }
                    });
                } else {
                    if (onFailure) {
                        onFailure(originalRequest, response, error, JSON);
                    }
                }
            } else if ([error domain] == NSURLErrorDomain && [error code] == -1009) {
                if (onFailure) {
                    NSError *networkNotReachableError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[error userInfo]];
                    onFailure(originalRequest, response, networkNotReachableError, JSON);
                }
            } else {
                if (onFailure) {
                    onFailure(originalRequest, response, error, JSON);
                }
            }
        };
        
        AFJSONRequestOperation *op = [SMJSONRequestOperation JSONRequestOperationWithRequest:request success:onSuccess failure:retryBlock];
        if (successCallbackQueue) {
            [op setSuccessCallbackQueue:successCallbackQueue];
        }
        if (failureCallbackQueue) {
            [op setFailureCallbackQueue:failureCallbackQueue];
        }
        [[self.session oauthClientWithHTTPS:options.isSecure] enqueueHTTPRequestOperation:op];
    }
    
}

- (void)queueCustomCodeRequest:(NSURLRequest *)request customCodeRequestInstance:(SMCustomCodeRequest *)customCodeRequest options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMFullResponseSuccessBlock)onSuccess onFailure:(SMFullResponseFailureBlock)onFailure
{
    if ([self.session eligibleForTokenRefresh:options]) {
        [self refreshAndRetryCustomCode:request customCodeRequestInstance:customCodeRequest originalError:nil requestSuccessCallbackQueue:successCallbackQueue requestFailureCallbackQueue:failureCallbackQueue options:options onSuccess:onSuccess onFailure:onFailure];
    }
    else {
        AFHTTPOperationSuccessBlock successBlock = ^(AFHTTPRequestOperation *operation, id responseObject){
            
            // Remove any custom content types
            if (customCodeRequest.responseContentType) {
                [AFHTTPRequestOperation removeAcceptableContentType:customCodeRequest.responseContentType];
            }
            
            NSString *contentType = [[[operation response] allHeaderFields] objectForKey:@"Content-Type"];
            if ([contentType rangeOfString:SM_VENDOR_SPECIFIC_JSON].location != NSNotFound || [contentType rangeOfString:SM_JSON].location != NSNotFound) {
                id returnValue = nil;
                NSError *error = nil;
                returnValue = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:&error];
                if (error) {
                    if (onFailure) {
                        dispatch_async(failureCallbackQueue, ^{
                            onFailure([operation request], [operation response], error, nil);
                        });
                    }
                } else if (onSuccess) {
                    onSuccess(operation.request, operation.response, returnValue);
                }
                
            } else if ([contentType rangeOfString:SM_TEXT_PLAIN].location != NSNotFound) {
                if (onSuccess) {
                    NSString *returnValue = nil;
                    returnValue = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                    onSuccess(operation.request, operation.response, returnValue);
                }
            } else if (onSuccess) {
                onSuccess(operation.request, operation.response, responseObject);
            }
        };
        
        AFHTTPOperationFailureBlock retryBlock = ^(AFHTTPRequestOperation *operation, NSError *error){
            
            // Remove any custom content types
            if (customCodeRequest.responseContentType) {
                [AFHTTPRequestOperation removeAcceptableContentType:customCodeRequest.responseContentType];
            }
            
            if ([[operation response] statusCode] == SMErrorUnauthorized && options.tryRefreshToken && self.session.refreshToken != nil) {
                [self refreshAndRetryCustomCode:[operation request] customCodeRequestInstance:customCodeRequest originalError:error requestSuccessCallbackQueue:successCallbackQueue requestFailureCallbackQueue:failureCallbackQueue options:options onSuccess:onSuccess onFailure:onFailure];
            } else if ([[operation response] statusCode] == SMErrorServiceUnavailable && options.numberOfRetries > 0) {
                NSString *retryAfter = [[[operation response] allHeaderFields] valueForKey:@"Retry-After"];
                if (retryAfter) {
                    dispatch_queue_t retryQueue = dispatch_queue_create("com.stackmob.retry", NULL);
                    [options setNumberOfRetries:(options.numberOfRetries - 1)];
                    double delayInSeconds = [retryAfter doubleValue];
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                    dispatch_after(popTime, retryQueue, ^(void){
                        if (options.retryBlock) {
                            options.retryBlock([operation request], [operation response], error, nil, options, onSuccess, onFailure);
                        } else {
                            [self queueCustomCodeRequest:[self.session signRequest:[operation request]] customCodeRequestInstance:customCodeRequest options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:onSuccess onFailure:onFailure];
                        }
                    });
                } else {
                    if (onFailure) {
                        onFailure([operation request], [operation response], error, nil);
                    }
                }
            } else if ([error domain] == NSURLErrorDomain && [error code] == -1009) {
                if (onFailure) {
                    NSError *networkNotReachableError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[error userInfo]];
                    onFailure([operation request], [operation response], networkNotReachableError, nil);
                }
            } else {
                if (onFailure) {
                    onFailure([operation request], [operation response], error, nil);
                }
            }
        };
        
        AFHTTPRequestOperation *op = [[self.session oauthClientWithHTTPS:options.isSecure] HTTPRequestOperationWithRequest:request success:successBlock failure:retryBlock];
        
        NSSet *whitelistedContentTypes = [NSSet setWithObjects:SM_VENDOR_SPECIFIC_JSON, SM_JSON, SM_TEXT_PLAIN, SM_OCTET_STREAM, nil];
        if (customCodeRequest.responseContentType) {
            [AFHTTPRequestOperation addAcceptableContentTypes:[whitelistedContentTypes setByAddingObject:customCodeRequest.responseContentType]];
        } else {
            [AFHTTPRequestOperation addAcceptableContentTypes:whitelistedContentTypes];
        }
        
        if (successCallbackQueue) {
            [op setSuccessCallbackQueue:successCallbackQueue];
        }
        if (failureCallbackQueue) {
            [op setFailureCallbackQueue:failureCallbackQueue];
        }
        [[self.session oauthClientWithHTTPS:options.isSecure] enqueueHTTPRequestOperation:op];
        
    }
    
}

- (NSString *)URLEncodedStringFromValue:(NSString *)value
{
    static NSString * const kAFCharactersToBeEscaped = @":/.?&=;+!@#$()~[]";
    
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)value, nil, (__bridge CFStringRef)kAFCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

// Operational methods

- (AFJSONRequestOperation *)postOperationForObject:(NSDictionary *)theObject inSchema:(NSString *)schema options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMCoreDataSaveFailureBlock)failureBlock
{
    
    if (theObject == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(nil, error, theObject, options, nil);
        }
        return nil;
    } else {
        NSString *theSchema = schema;
        if ([schema rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]].location == NSNotFound) {
            // lowercase the schema for StackMob
            theSchema = [theSchema lowercaseString];
        }
        
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"POST" path:theSchema parameters:theObject];
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForResultSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObject:theObject options:options originalSuccessBlock:successBlock coreDataSaveFailureBlock:failureBlock];
        return [self newOperationForRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}

- (AFJSONRequestOperation *)putOperationForObjectID:(NSString *)theObjectId inSchema:(NSString *)schema update:(NSDictionary *)updatedFields options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMCoreDataSaveFailureBlock)failureBlock
{
    if (theObjectId == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(nil, error, updatedFields, options, nil);
        }
        return nil;
    } else {
        NSString *path = [[schema lowercaseString] stringByAppendingPathComponent:[self URLEncodedStringFromValue:theObjectId]];
        
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"PUT" path:path parameters:updatedFields];
        
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForResultSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObject:updatedFields options:options originalSuccessBlock:successBlock coreDataSaveFailureBlock:failureBlock];
        return [self newOperationForRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}

- (AFJSONRequestOperation *)deleteOperationForObjectID:(NSString *)theObjectId inSchema:(NSString *)schema options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMCoreDataSaveFailureBlock)failureBlock
{
    if (theObjectId == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(nil, error, nil, options, nil);
        }
        return nil;
    } else {
        NSString *path = [[schema lowercaseString] stringByAppendingPathComponent:[self URLEncodedStringFromValue:theObjectId]];
        
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"DELETE" path:path parameters:nil];
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForResultSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObject:nil options:options originalSuccessBlock:successBlock coreDataSaveFailureBlock:failureBlock];
        return [self newOperationForRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}



@end

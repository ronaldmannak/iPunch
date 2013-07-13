//
//  REMCompileOnlineClient.m
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//

#import "REMCompileOnlineClient.h"

static NSString * const kiPunchAPIBaseURLString = @"http://www.compileonline.com";

@implementation REMCompileOnlineClient

+ (id)sharedClient {
    static REMCompileOnlineClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:kiPunchAPIBaseURLString]];
    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
//    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
//    [self setDefaultHeader:@"Accept" value:@"application/json"];
    
    return self;
}

- (id)compile:(NSData *)code
{
    /*
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:3];
    [dictionary addEntriesFromDictionary: @{@"uid" : self.token.uid,
     @"session_token" : self.token.sessionToken,
     @"q" : searchTerm
     }];
     */
    
//    NSMutableURLRequest *mutableURLRequest = [self requestWithMethod:@"POST" path:@" parameters:dictionary];
    
    

}

@end

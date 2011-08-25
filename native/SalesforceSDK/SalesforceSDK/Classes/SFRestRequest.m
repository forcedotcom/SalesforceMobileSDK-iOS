//
//  SFRestAPIRequest.m
//  SalesforceSDK
//
//  Created by Didier Prophete on 7/25/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFRestRequest.h"

#import "SBJson.h"

@implementation SFRestRequest

@synthesize queryParams=_queryParams;
@synthesize path=_path;
@synthesize method=_method;

- (id)initWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    self = [super init];
    if (self) {
        self.method = method;
        self.path = path;
        self.queryParams = queryParams;
    }
    return self;
}

- (void)dealloc {
    self.path = nil;
    self.queryParams = nil;
    [super dealloc];
}

+ (id)requestWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams {
    return [[[SFRestRequest alloc] initWithMethod:method path:path queryParams:queryParams] autorelease];
}

-(NSString *)description {
    NSString *methodName;
    switch (_method) {
        case SFRestMethodGET: methodName = @"GET"; break;
        case SFRestMethodPOST: methodName = @"POST"; break;
        case SFRestMethodPUT: methodName = @"PUT"; break;
        case SFRestMethodDELETE: methodName = @"DELETE"; break;
        case SFRestMethodHEAD: methodName = @"HEAD"; break;
        case SFRestMethodPATCH: methodName = @"PATCH"; break;
    }
    return [NSString stringWithFormat:@"[<SFRestRequest> method: %@, path: %@, queryParams: %@]", methodName, _path, [_queryParams JSONRepresentation]];
}
@end

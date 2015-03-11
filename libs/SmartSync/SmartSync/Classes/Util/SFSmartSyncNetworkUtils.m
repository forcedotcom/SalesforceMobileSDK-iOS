//
//  SFSmartSyncNetworkUtils.m
//  SmartSync
//
//  Created by Kevin Hawkins on 3/10/15.
//  Copyright (c) 2015 Salesforce Inc. All rights reserved.
//

#import "SFSmartSyncNetworkUtils.h"
#import <SalesforceRestAPI/SFRestAPI+Blocks.h>
#import <SalesforceRestAPI/SFRestRequest.h>

@implementation SFSmartSyncNetworkUtils

+ (void)sendRequestWithSmartSyncUserAgent:(SFRestRequest *)request failBlock:(void (^)(NSError *))failBlock completeBlock:(id)completeBlock {
    //[request setHeaderValue:[SFRestAPI userAgentString:kSmartSync] forHeaderName:kUserAgent];
    [[SFRestAPI sharedInstance] sendRESTRequest:request failBlock:failBlock completeBlock:completeBlock];
}

@end

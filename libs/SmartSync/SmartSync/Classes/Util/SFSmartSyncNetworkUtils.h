//
//  SFSmartSyncNetworkUtils.h
//  SmartSync
//
//  Created by Kevin Hawkins on 3/10/15.
//  Copyright (c) 2015 Salesforce Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SFRestRequest;

@interface SFSmartSyncNetworkUtils : NSObject

+ (void)sendRequestWithSmartSyncUserAgent:(SFRestRequest *)request failBlock:(void (^)(NSError *))failBlock completeBlock:(id)completeBlock;

@end

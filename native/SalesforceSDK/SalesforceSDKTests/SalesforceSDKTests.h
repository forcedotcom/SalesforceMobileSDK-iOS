//
//  SalesforceSDKTests.h
//  SalesforceSDKTests
//
//  Created by Didier Prophete on 7/20/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "SFRestAPI.h"

@interface SalesforceSDKTests : SenTestCase <SFRestDelegate> {
    // async/sync wrapper
    id _apiJsonResponse;
    NSError *_apiError;
    SFRestRequest *_apiErrorRequest;
    NSString *_apiReturnStatus;
    
@private
    
}

@property (nonatomic, retain) id apiJsonResponse;
@property (nonatomic, retain) NSError *apiError;
@property (nonatomic, retain) SFRestRequest *apiErrorRequest;
@property (nonatomic, retain) NSString *apiReturnStatus;

@end

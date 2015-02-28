
#import "SFDataManager.h"

#import <ReactKit/RCTAssert.h>
#import <ReactKit/RCTLog.h>
#import <ReactKit/RCTUtils.h>

#import <SalesforceRestAPI/SFRestAPI+Blocks.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
//#import <SalesforceRestAPI/SFRestRequest.h>


@implementation SFDataManager


- (void)get:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();

    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:[args valueForKey:@"path"] queryParams:[args valueForKey:@"queryParams"]];

    [[SFRestAPI sharedInstance] sendRESTRequest:request failBlock:^(NSError *e) {
        callbackErr(@[@{@"err":@"ERROR"}]);
    } completeBlock:^(id dataResponse) {
        if (nil != dataResponse) {
            callback(@[RCTJSONStringify(dataResponse, NULL)]);
        }
    }];
        
}

- (void)query:(NSDictionary *)args callback:(RCTResponseSenderBlock)callback callbackErr:(RCTResponseSenderBlock)callbackErr
{
    RCT_EXPORT();
    
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:[args valueForKey:@"query"]];
    
    [[SFRestAPI sharedInstance] sendRESTRequest:request failBlock:^(NSError *e) {
        callbackErr(@[@{@"err":@"ERROR"}]);
        [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *authInfo) {
//            [request send:_networkEngine];
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            [[SFAuthenticationManager sharedManager] logout];
        }];
    } completeBlock:^(id dataResponse) {
        if (nil != dataResponse) {
            callback(@[RCTJSONStringify(dataResponse, NULL)]);
        }
    }];
    
}

- (NSString *)getFormatted:(NSDictionary *)args{
    RCT_EXPORT();
    return @"YES!";
}

+ (NSString *)getFullName{
    return @"AAAA!!!";
}
//- (SFRestRequest *)requestForQuery:(NSString *)soql;
@end

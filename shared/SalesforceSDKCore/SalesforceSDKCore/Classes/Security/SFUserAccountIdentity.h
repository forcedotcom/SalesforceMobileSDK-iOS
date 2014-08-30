//
//  SFUserAccountIdentity.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 8/29/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SFUserAccount;

@interface SFUserAccountIdentity : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *orgId;

+ (SFUserAccountIdentity *)identityFromUserAccount:(SFUserAccount *)account;

- (id)initWithUserId:(NSString *)userId orgId:(NSString *)orgId;

@end

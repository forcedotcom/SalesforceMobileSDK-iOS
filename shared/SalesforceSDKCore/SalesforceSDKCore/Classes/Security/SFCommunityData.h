//
//  SFCommunityData.h
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 2/5/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Class that groups the data describing a community
 */
@interface SFCommunityData : NSObject <NSCoding>

/** The community ID
 */
@property (nonatomic, strong) NSString *entityId;

/** The community name
 */
@property (nonatomic, strong) NSString *name;

/** The community description
 */
@property (nonatomic, strong) NSString *description;

/** The community siteUrl
 */
@property (nonatomic, strong) NSURL *siteUrl;

@property (nonatomic, strong) NSURL *url;

@property (nonatomic, strong) NSURL *urlPathPrefix;

/** Flag indicating if the community is live or not
 */
@property (nonatomic) BOOL enabled;

@property (nonatomic) BOOL invitationsEnabled;

@property (nonatomic) BOOL sendWelcomeEmail;

@end

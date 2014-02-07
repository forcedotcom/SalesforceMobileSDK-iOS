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
@property (nonatomic, strong) NSString *identifier;

/** The community name
 */
@property (nonatomic, strong) NSString *name;

/** The community siteUrl
 */
@property (nonatomic, strong) NSURL *siteUrl;

/** Flag indicating if the community is live or not
 */
@property (nonatomic) BOOL enabled;

+ (instancetype)communityData;

@end

//
//  SFPasscodeData.h
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 1/31/13.
//  Copyright (c) 2013 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFPBKDFData : NSObject <NSCoding>

@property (nonatomic, retain) NSData *derivedKey;
@property (nonatomic, retain) NSData *salt;
@property (nonatomic, assign) NSUInteger *numDerivationRounds;

@end

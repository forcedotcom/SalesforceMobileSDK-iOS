//
//  SalesforceOAuthPlugin.h
//  VFWithOAuthPlugin
//
//  Created by Kevin Hawkins on 11/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PhoneGap/PGPlugin.h>


@interface SalesforceOAuthPlugin : PGPlugin {
    NSString *_callbackId;
}

@property (nonatomic, copy) NSString* callbackId;

- (void)getLoginHost:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end

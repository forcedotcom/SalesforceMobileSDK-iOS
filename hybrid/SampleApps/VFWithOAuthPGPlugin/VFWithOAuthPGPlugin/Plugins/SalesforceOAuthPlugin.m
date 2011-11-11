//
//  SalesforceOAuthPlugin.m
//  VFWithOAuthPlugin
//
//  Created by Kevin Hawkins on 11/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <PhoneGap/PGPlugin.h>

#import "SalesforceOAuthPlugin.h"
#import "AppDelegate.h"


@implementation SalesforceOAuthPlugin

@synthesize callbackId=_callbackId;

-(void)getLoginHost:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options  
{
    self.callbackId = [arguments pop];
    
    // TODO: move oauthLoginDomain retrieval logic to this plug-in.
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    NSString *loginHost = [appDelegate oauthLoginDomain];
    
    PluginResult *pluginResult = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsString:[loginHost stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [self writeJavascript:[pluginResult toSuccessCallbackString:self.callbackId]];
}

@end

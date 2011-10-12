//
//  AppDelegate.h
//  VisualForceConnector
//
//  Created by Kevin Hawkins on 10/11/11.
//  Copyright __MyCompanyName__ 2011. All rights reserved.
//

#import <UIKit/UIKit.h>
#ifdef PHONEGAP_FRAMEWORK
	#import <PhoneGap/PhoneGapDelegate.h>
#else
	#import "PhoneGapDelegate.h"
#endif

#import "SFOAuthCoordinator.h"

@interface AppDelegate : PhoneGapDelegate <SFOAuthCoordinatorDelegate, UIAlertViewDelegate> {

	NSString* invokeString;
    SFOAuthCoordinator *_coordinator;
}

// invoke string is passed to your app on launch, this is only valid if you 
// edit VisualForceConnector.plist to add a protocol
// a simple tutorial can be found here : 
// http://iphonedevelopertips.com/cocoa/launching-your-own-application-via-a-custom-url-scheme.html

@property (copy)  NSString* invokeString;
@property (nonatomic, retain) SFOAuthCoordinator *coordinator;

@end


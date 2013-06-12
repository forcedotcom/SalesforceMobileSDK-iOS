//
//  SFDeviceInfo.h
//  SalesforceCommonUtils
//
//  Created by Jason Schroeder on 8/30/10.
//  Copyright (c) 2010-2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

/**This is a utility class that check whether some capability is supported on the current device
 */
@interface SFDeviceInfo : NSObject {
	
}
/**Return YES if device has facetime capability
 */
+ (BOOL)canHandleFacetimeUrls;

/**Return YES if device has telephone capability
 */
+ (BOOL)canHandleTelUrls;

/**Return YES if device has SMS capability
 */
+ (BOOL)canHandleSmsUrls;

/**Return YES if device is iPad
 */
+ (BOOL)currentDeviceIsIPad;

/**Return YES if device is retina enabled device*/
+ (BOOL)isRetina;

/**Return YES if device has been set up for sending text only messages
 */
+ (BOOL)canSendMessage;

@end


//
//  SFSDKLoginViewControllerConfig.h
//  SalesforceSDKCore
//
//  Created by Raj Rao on 11/15/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSDKLoginViewControllerConfig : NSObject

/** Specify the font to use for navigation bar header text.*/
@property (nonatomic, strong, nullable) UIFont * navBarFont;

/** Specify the text color to use for navigation bar header text. */
@property (nonatomic, strong, nullable) UIColor * navBarTextColor;

/** Specify navigation bar color. This color will be used by the login view header.
 */
@property (nonatomic, strong, nullable) UIColor *navBarColor;

/** Specify visibility of nav bar. This property will be used to hide/show the nav bar*/
@property (nonatomic) BOOL showNavbar;

/** Specifiy the visibility of the settings icon. This property will be used to hide/show the settings icon*/
@property (nonatomic) BOOL showSettingsIcon;



@end

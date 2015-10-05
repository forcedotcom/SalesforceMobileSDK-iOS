//
//  SFGradientView.h
//  SalesforceCommonUtils
//
//  Created by Michael Nachbaur on 12/9/11.
//  Copyright (c) 2011-2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

/**  This view is designed to create a view with gradient colors and locations 
    that could be used as background view of another view
 */
@interface SFGradientView : UIView

/**Array of graident colors. 
 
Each object should be of CGColor type
*/
@property (nonatomic, retain) NSArray *colors;

/**Array of graident colors stops. 
 
 Locations count should match colors count
 */
@property (nonatomic, retain) NSArray *locations;

@end

//
//  NSURL+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 9/24/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (SFAdditions)

/** Get value for a parameter name from the URL
 */
- (NSString*)valueForParameterName:(NSString*)name;

@end

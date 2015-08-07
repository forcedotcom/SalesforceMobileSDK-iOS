//
//  NSString+SFPathAdditions.h
//  SalesforceCommonUtils
//
//  Created by Sachin Desai on 5/7/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**Extension to NSString object for URL path related feature
 */
@interface NSString (SFPathAdditions)



/**Encode file name escape special character that is not allowed in file name
 */
- (NSString *)encodeToPercentEscapeString;

/**Decode file name to unescape escape character to get the real file name
 */
- (NSString *)decodeFromPercentString;

@end

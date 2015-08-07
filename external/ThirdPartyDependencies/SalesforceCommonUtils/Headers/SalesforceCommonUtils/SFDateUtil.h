//
//  SFDateUtil.h
//  SalesforceCommonUtils
//
//  Created by Qingqing Liu on 4/24/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**This is utility class for conversion between local date and server SOQL data
 */

@interface SFDateUtil : NSObject
/**Convert NSDate to string that conforms to SOQL date required format
 
This method will convert the specified date to a GMT date and time string
@param date Date to convert to string
@param isDateTime Yes if converted string should contain both date and time. 
 No, converted string will contains only date part
 */
+ (NSString *)toSOQLDateTimeString:(NSDate *)date isDateTime:(BOOL)isDateTime;

/**Convert NSString in SOQL date format into NSDate with device's default timezone
 
 This method will take care of timezone conversion from GMT timezone to device's default time zone
 @param soqlDateTimeString String object in SOQL date foramt.
 
 An example of supported SOQL datetime: 2011-01-24T17:34:14.000Z
 Another example of support SOQL datetime is: 2012-04-16T23:24:52.000+0000
 An example of supported SOQL date: 2011-01-24
 */
+ (NSDate *)SOQLDateTimeStringToDate:(NSString *)soqlDateTimeString;

/**Create a NSDate object with device's default timezone from a double value that is the NSTimeIntervalSince1970 */
+ (NSDate *)createDateFromDouble:(double)doubleValue;
@end

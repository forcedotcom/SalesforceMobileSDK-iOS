/*
 * Copyright, 2008-2011, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */
#import <UIKit/UIKit.h>


@interface SFPathUtil : NSObject {
    
}

/*!
 returns the absolute path for a file located in the apps document directory
 it also ensures that the documents directory exists
 */
+(NSString *)absolutePathForDocumentFile:(NSString *)file;

/*!
 returns the absolute path for a directory/folder located in the apps document directory
 it also ensures this sub-directory exists
 */
+(NSString *)absolutePathForDocumentFolder:(NSString *)folder;

@end

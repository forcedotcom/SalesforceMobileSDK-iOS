/*
 * Copyright, 2008-2011, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */

#import "SFPathUtil.h"


@implementation SFPathUtil

+(NSString *)absolutePathForDocumentFile:(NSString *)file {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory]) 
		[[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
	return [documentsDirectory stringByAppendingPathComponent:file];
}

+(NSString *)absolutePathForDocumentFolder:(NSString *)folder {
	NSString *dir = [SFPathUtil absolutePathForDocumentFile:folder];
	if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) 
		[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

@end

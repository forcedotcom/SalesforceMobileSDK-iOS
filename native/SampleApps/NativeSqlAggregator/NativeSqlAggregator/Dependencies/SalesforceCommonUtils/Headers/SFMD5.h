//
//  SFMD5.h
//  SalesforceCommonUtils
//
//  Created by Sachin Desai on 6/19/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kFileHashDefaultChunkSizeForReadingData  4096

@interface SFMD5 : NSObject

+(NSString *) md5HashForFile:(NSString *) filePath chunkSize:(NSInteger) chunkSize;

@end

/*
 * Copyright, 2008, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */

#import <UIKit/UIKit.h>


@interface NSData (SFBase64)


/*!
 @abstract Create a new base64 encoding of this NSData that is not left in the autorelease pool
 */
-(NSString *)newBase64Encoding;

/*!
 @abstract Same as newBase64Encoding but returns autorelease string
 */
-(NSString *)base64Encode;

/*!
 @abstract Initialize NSData from a base64-encoded string
 */
-(id)initWithBase64String:(NSString *)base64;

@end

@interface NSData (SFMD5)

-(NSString *)md5;

@end

@interface NSData (SFzlib)

-(NSData *)gzipDeflate;

@end


@interface NSData (SFHexSupport)

/*!
 @abstract Return a hex string representation of the data contained in receiver
 */
- (NSString*)newHexStringFromBytes;

@end

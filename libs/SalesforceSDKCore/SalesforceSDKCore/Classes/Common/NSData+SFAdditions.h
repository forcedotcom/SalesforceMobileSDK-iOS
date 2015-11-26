/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>

/**Extension to NSData class to provide common functions
 
 Added functionalities include 
 base64 encode of a NSData
 MD5 of a NSData
 Gzip deflat of a gzip compressed NSData
 Hex version of a NSData
 */
@interface NSData (SFBase64)

/**
 @return The specified number of random bytes or `nil` if an error occurs.
 */
- (NSData *)randomDataOfLength:(size_t)length;

/**Create a new base64 encoding of this NSData
 */
-(NSString *)newBase64Encoding;

/**Return base64 encoded string for the currrent NSData
 */
-(NSString *)base64Encode;

/**Create a new base64 encoding of this NSData. 
 
 Similar to `newBase64Encoding`
 */
-(id)initWithBase64String:(NSString *)base64;

+(NSData *)dataFromBase64String:(NSString *)encoding;

@end


@interface NSData (SFMD5)

/**Return md5 version of this NSData*/
- (NSString *)md5;
@end

@interface NSData (SFzlib)

/**Return gzip uncompressed version of the this NSData*/
-(NSData *)gzipInflate;
/**Return gzip compressed version of the this NSData*/
-(NSData *)gzipDeflate;
@end


@interface NSData (SFHexSupport)

/** Return a hex string representation of the data contained in receiver
 */
- (NSString*)newHexStringFromBytes;

@end

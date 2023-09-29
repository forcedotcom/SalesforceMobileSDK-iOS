/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
NS_ASSUME_NONNULL_BEGIN

/** Extension to NSData class to provide common functions. Added functionality includes:
 --base64 encoding of an NSData object
 --MD5 version of an NSData object
 --Gzip deflated representation of a gzip-compressed NSData object
 --Hex version of an NSData object
 */
@interface NSData (SFBase64)

/** Returns a specified number of random bytes.
 @param length The number of bytes of random data to return.
 @return The specified quantity of random bytes or `nil` if an error occurs.
 */
- (nullable NSData *)sfsdk_randomDataOfLength:(size_t)length;

- (nullable NSData *)randomDataOfLength:(size_t)length SFSDK_DEPRECATED(11.1, 12.0, "Use sfsdk_randomDataOfLength: instead");


/**Creates a base64 encoded string for this NSData object.
 @return A base64 encoded version of the data.
 */
-(NSString *)newBase64Encoding SFSDK_DEPRECATED(11.1, 12.0, "Will be removed");

/**Returns a base64 encoded string for this NSData object.
 @return A base64 encoded version of the data.
 */
-(NSString *)base64Encode SFSDK_DEPRECATED(11.1, 12.0, "Will be removed");

/**Creates a base64 encoding of this NSData. Similar to newBase64Encoding.
 @param base64 The base64 encoding to use in the new NSData object.
 @return The base64 encoded NSData object. 
 */
-(id)initWithBase64String:(NSString *)base64 SFSDK_DEPRECATED(11.1, 12.0, "Will be removed");

/** Creates an NSData object from a base64 encoded string.
 @param encoding The string to convert to NSData.
 @return A base64-encoded string version of this object's data.
 */
+(NSData *)dataFromBase64String:(NSString *)encoding SFSDK_DEPRECATED(11.1, 12.0, "Will be removed");

@end

/** Provides MD5 conversion support.
 */
@interface NSData (SFSHA)

/** Derives  a  sha1  hex encoded string.
 @return md5 version of data.
 */
-(NSString *)sha1 SFSDK_DEPRECATED(11.1, 12.0, "Will be removed");

/**Derives  a  sha224  hex encoded string.
 @return md5 version of data.
 */
-(NSString *)sha224 SFSDK_DEPRECATED(11.1, 12.0, "Will be removed");

/**Derives  a  sha256  hex encoded string.
 @return md5 version of data.
 */
-(NSString *)sfsdk_sha256;

-(NSString *)sha256 SFSDK_DEPRECATED(11.1, 12.0, "Use sfsdk_sha256 instead");


@end

/** Provides gzip uncompressed conversion support.
 */
@interface NSData (SFzlib)
/**Converts this data to gzip uncompressed format.
 @return This data in gzip uncompressed format.
*/
- (nullable NSData *)sfsdk_gzipInflate;

- (nullable NSData *)gzipInflate SFSDK_DEPRECATED(11.1, 12.0, "Use sfsdk_gzipInflate instead");

/**Converts this data to gzip compressed format.
 @return This data in gzip compressed format.
 */
- (nullable NSData *)sfsdk_gzipDeflate;

- (nullable NSData *)gzipDeflate SFSDK_DEPRECATED(11.1, 12.0, "Use sfsdk_gzipDeflate instead");
@end

/**
 Provides hex string conversion support.
 */
@interface NSData (SFHexSupport)
/** Creates a hex string representation of this object's data.
 @return Hex string representation of this object's data.
 */
- (NSString*)sfsdk_newHexStringFromBytes;

- (NSString*)newHexStringFromBytes SFSDK_DEPRECATED(11.1, 12.0, "Use sfsdk_newHexStringFromBytes instead");

@end

NS_ASSUME_NONNULL_END

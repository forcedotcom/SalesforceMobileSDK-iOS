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

#import "NSData+SFAdditions.h"
#define COMMON_DIGEST_FOR_OPENSSL
#import <CommonCrypto/CommonDigest.h>

#import "SFLogger.h"
#include "zlib.h"

// Map 8-bit character to 6-bit byte
#define INVALID_BYTE64 255
#define OFFSET_BYTE64  '+'

typedef unsigned char BYTE;

static const BYTE g_byteMap64[] = {
    62, // +
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    63, // /
    52, // 0
    53, // 1
    54, // 2
    55, // 3
    56, // 4
    57, // 5
    58, // 6
    59, // 7
    60, // 8
    61, // 9
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    0,  // A
    1,  // B
    2,  // C
    3,  // D
    4,  // E
    5,  // F
    6,  // G
    7,  // H
    8,  // I
    9,  // J
    10, // K
    11, // L
    12, // M
    13, // N
    14, // O
    15, // P
    16, // Q
    17, // R
    18, // S
    19, // T
    20, // U
    21, // V
    22, // W
    23, // X
    24, // Y
    25, // Z
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    INVALID_BYTE64,
    26, // a
    27, // b
    28, // c
    29, // d
    30, // e
    31, // f
    32, // g
    33, // h
    34, // i
    35, // j
    36, // k
    37, // l
    38, // m
    39, // n
    40, // o
    41, // p
    42, // q
    43, // r
    44, // s
    45, // t
    46, // u
    47, // v
    48, // w
    49, // x
    50, // y
    51, // z
};

static const int g_byteMapSize = sizeof(g_byteMap64)/sizeof(*g_byteMap64) ;

static const char g_szMap[]  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";


int decode64(BYTE* decData, const char* srcData);
// encode 1,2,3 or bytes from srcData into encData
// @param numBytes Number of bytes to encode (1, 2 or 3)
void encode64(char *encData, const BYTE* srcData, size_t numBytes ) ;

// Base64 encode a buffer of bytes where cch >= (cb/3) * 4.
void bufferEncode64(char *destData, size_t destLen, const BYTE *srcData, size_t srcLen);


// Base64 decode a buffer of characters where *pcb >= (cch/4) * 3.
// NOTE: On input, *destLen is assumed to be the maximum size of destData.
void bufferDecode64(BYTE *destData, size_t *destLen, const char *srcData, size_t srcLen);

// encode 1,2,3 or bytes from srcData into encData
void encode64(char *encData, const BYTE* srcData, size_t numBytes ) { // Number of bytes to encode (1, 2 or 3)

	assert (numBytes >=1 && numBytes <=3);
	assert (encData);
	assert (srcData);

    // Break out three 8-bit bytes into four characters using 6-bit bytes,
    // padding with the = character should less than 3 bytes be encoded.
	encData[0] = g_szMap[((srcData[0] >> 2))];
    switch( numBytes )
    {
    case 3:
        encData[1] = g_szMap[((srcData[0] & 0x03) << 4) | (srcData[1] >> 4)];
        encData[2] = g_szMap[((srcData[1] & 0x0f) << 2) | (srcData[2] >> 6)];
        encData[3] = g_szMap[((srcData[2] & 0x3f))];
		break;

    case 2:
        encData[1] = g_szMap[((srcData[0] & 0x03) << 4) | (srcData[1] >> 4)];
        encData[2] = g_szMap[((srcData[1] & 0x0f) << 2)];
        encData[3] = '=';
		break;

    case 1:
        encData[1] = g_szMap[((srcData[0] & 0x03) << 4)];
        encData[2] = '=';
        encData[3] = '=';
    }
}

// Turn four characters in the range [A-Za-z0-9+/] into n bytes,
// stopping when the = padding character is reached.
int decode64(BYTE* decData, const char* srcData) {
	assert (srcData);
	assert (decData);

    // Translate four characters into four 6-bit bytes
	int numBytes = 0;
    BYTE rgbTmp[4];
    size_t cch = 0;    // Count of characters to decode (stop at padding)

    for (int i = 0; srcData[i] != '=' && i < 4; i++, cch++ ) {
        size_t  n = srcData[i] - OFFSET_BYTE64;
        if( n >= g_byteMapSize || ((rgbTmp[i] = g_byteMap64[n]) == INVALID_BYTE64) )
            return -1;
    }

    // Translate 6-bit bytes into 8-bit bytes
	switch( cch ) {
        case 4:
            decData[0] = (rgbTmp[0] << 2) | (rgbTmp[1] >> 4);
            decData[1] = (rgbTmp[1] << 4) | (rgbTmp[2] >> 2);
            decData[2] = (rgbTmp[2] << 6) | (rgbTmp[3] >> 0);
            numBytes = 3;
			break;

        case 3:
            decData[0] = (rgbTmp[0] << 2) | (rgbTmp[1] >> 4);
            decData[1] = (rgbTmp[1] << 4) | (rgbTmp[2] >> 2);
            numBytes = 2;
		    break;

        case 2:
            decData[0] = (rgbTmp[0] << 2) | (rgbTmp[1] >> 4);
            numBytes = 1;
	        break;
    }
	return numBytes;
}

// Base64 encode a buffer of bytes where cch >= (cb/3) * 4.
void bufferEncode64(char *destData, size_t destLen, const BYTE *srcData, size_t srcLen) {
	assert (destLen % 4 == 0);
	assert (destLen >= (srcLen/3 * 4)) ;
	assert (srcData);
	assert (destData);

    size_t  nRaw;
    size_t  nEncoded;
    for( nRaw = 0, nEncoded = 0; (nRaw + 2) < srcLen; nRaw += 3, nEncoded += 4)
        encode64(destData + nEncoded, srcData + nRaw, 3);

    // Catch the last 1 or 2 bytes
    if(srcLen - nRaw)
		encode64(destData + nEncoded, srcData + nRaw, srcLen - nRaw);
}

// Base64 decode a buffer of characters where *pcb >= (cch/4) * 3.
// NOTE: On input, *destLen is assumed to be the maximum size of destData.
void bufferDecode64(BYTE *destData, size_t *destLen, const char *srcData, size_t srcLen) {
	assert(destData);
	assert(srcData);
	assert(srcLen);
	assert ( *destLen >= (srcLen/4 * 3) - 2 ) ;

    *destLen = 0;
    size_t  nRaw, nEncoded, cb;

    for( nRaw = 0, nEncoded = 0; nEncoded < srcLen; nRaw += 3, nEncoded += 4) {    
        cb = decode64(destData + nRaw, srcData + nEncoded);
		*destLen += cb;
        if (cb < 3) break;
    }
}

@implementation NSData (SFBase64)

- (NSData *)randomDataOfLength:(size_t)length {
    NSMutableData *data = [NSMutableData dataWithData:self];
    int result = SecRandomCopyBytes(kSecRandomDefault, length, [data mutableBytes]);
    if (result != 0) {
        [self log:SFLogLevelWarning format:@"Failed to generate random bytes (errno = %d)", errno];
        return nil;
    }
    return data;
}

-(NSString *)newBase64Encoding {
	NSUInteger sl = [self length];
	size_t destLen = sl % 3 == 0 ? sl/3*4 : ((sl/3)+1)*4;
	char *buff = malloc(destLen);
	bufferEncode64(buff, destLen, [self bytes], sl);
	NSString *result = [[NSString alloc] initWithBytesNoCopy:buff length:destLen encoding:NSASCIIStringEncoding freeWhenDone:YES];
	return result;
}

-(NSString *)base64Encode {
	NSString *result = [self newBase64Encoding];
    return result;
}

-(id)initWithBase64String:(NSString *)base64 {
	NSUInteger sl = [base64 length];
	if (sl == 0)
		return [self initWithBytes:NULL length:0];
	size_t destLen = sl/4*3;
	BYTE *buff = malloc(destLen);
	bufferDecode64(buff, &destLen, [base64 cStringUsingEncoding:NSASCIIStringEncoding], sl);
	return [self initWithBytesNoCopy:buff length:destLen freeWhenDone:YES];
}

+(NSData *)dataFromBase64String:(NSString *)encoding
{
    NSData *data = nil;
    unsigned char *decodedBytes = NULL;
    @try {
#define __ 255
        static char decodingTable[256] = {
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x00 - 0x0F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x10 - 0x1F
            __,__,__,__, __,__,__,__, __,__,__,62, __,__,__,63,  // 0x20 - 0x2F
            52,53,54,55, 56,57,58,59, 60,61,__,__, __, 0,__,__,  // 0x30 - 0x3F
            __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x40 - 0x4F
            15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x50 - 0x5F
            __,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,  // 0x60 - 0x6F
            41,42,43,44, 45,46,47,48, 49,50,51,__, __,__,__,__,  // 0x70 - 0x7F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x80 - 0x8F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x90 - 0x9F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xA0 - 0xAF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xB0 - 0xBF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xC0 - 0xCF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xD0 - 0xDF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xE0 - 0xEF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xF0 - 0xFF
        };
        NSData *encodedData = [encoding dataUsingEncoding:NSASCIIStringEncoding];
        unsigned char *encodedBytes = (unsigned char *)[encodedData bytes];
        
        NSUInteger encodedLength = [encodedData length];
        NSUInteger encodedBlocks = (encodedLength+3) >> 2;
        NSUInteger expectedDataLength = encodedBlocks * 3;
        
        unsigned char decodingBlock[4];
        
        decodedBytes = malloc(expectedDataLength);
        if( decodedBytes != NULL ) {
            
            NSUInteger i = 0;
            NSUInteger j = 0;
            NSUInteger k = 0;
            unsigned char c;
            while( i < encodedLength ) {
                c = decodingTable[encodedBytes[i]];
                i++;
                if( c != __ ) {
                    decodingBlock[j] = c;
                    j++;
                    if( j == 4 ) {
                        decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                        decodedBytes[k+1] = (decodingBlock[1] << 4) | (decodingBlock[2] >> 2);
                        decodedBytes[k+2] = (decodingBlock[2] << 6) | (decodingBlock[3]);
                        j = 0;
                        k += 3;
                    }
                }
            }
            
            // Process left over bytes, if any
            if( j == 3 ) {
                decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                decodedBytes[k+1] = (decodingBlock[1] << 4) | (decodingBlock[2] >> 2);
                k += 2;
            } else if( j == 2 ) {
                decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                k += 1;
            }
            data = [[NSData alloc] initWithBytes:decodedBytes length:k];
        }
    }
    @catch (NSException *exception) {
        data = nil;
        [self log:SFLogLevelDebug format:@"WARNING: error occured while decoding base 32 string: %@", exception];
    }
    @finally {
        if( decodedBytes != NULL ) {
            free( decodedBytes );
        }
    }
    return data;
}

@end


@implementation NSData (SFMD5)

-(NSString *)md5 {
	unsigned char digest[MD5_DIGEST_LENGTH];
	digest[0] = 0;
    CC_MD5([self bytes], (CC_LONG)[self length], digest);
    NSMutableString *ms = [NSMutableString string];
    for(int i = 0; i < MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", digest[i]];
    }
    return [ms copy];
}

@end

@implementation NSData (SFzlib)
- (NSData *) gzipInflate {
    if ([self length] == 0) {
        return self;
    }
    
    unsigned full_length = (uInt)[self length];
    unsigned half_length = (uInt)[self length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[self bytes];
    strm.avail_in = (uInt)[self length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
    while (!done) {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
    
    // Set real length.
    if (done) {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    else return nil;
}

-(NSData *)gzipDeflate {
	z_stream stream;
	stream.zalloc = Z_NULL;
	stream.zfree = Z_NULL;
	stream.opaque = Z_NULL;
	stream.total_out = 0;
	// input buffer:
	stream.next_in = (Bytef*)[self bytes];
	// length of input buffer:
	stream.avail_in = (uInt)[self length];
	
	int deflateStatus = deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
	if (deflateStatus != Z_OK) {
		[self log:SFLogLevelError format:@"cannot initialize zlib deflate: %d", deflateStatus];
		return nil;
	}

    NSMutableData *compressedData = [NSMutableData dataWithLength:16384];
	
    do {  
		if (stream.total_out >= [compressedData length]) {
			[compressedData increaseLengthBy:16384];
		}
        // Store location where next byte should be put in next_out  
        stream.next_out = [compressedData mutableBytes] + stream.total_out;  
        stream.avail_out = (uInt)([compressedData length] - stream.total_out);
		
        deflateStatus = deflate(&stream, Z_FINISH);  
		
    } while (deflateStatus == Z_OK);
	if (deflateStatus != Z_STREAM_END) {
		// there was some error compressing. let's log it.
		[self log:SFLogLevelError format:@"couldn't compress input: zlib error %d: %s", deflateStatus, stream.msg];
		deflateEnd(&stream);
		return nil;
	}
	deflateEnd(&stream);  
    [compressedData setLength:stream.total_out];
    [self log:SFLogLevelDebug format:@"%s: Compressed file from %d KB to %d KB", __func__, ([self length]/1024), ([compressedData length]/1024)];
    return compressedData;  
}

@end



@implementation NSData (SFHexSupport)

- (NSString*)newHexStringFromBytes {
	NSUInteger dataLen = [self length];
	NSMutableString *sb = [[NSMutableString alloc] initWithCapacity:(2 * dataLen )];
	const unsigned char *rawBytes = [self bytes];	
	for (NSUInteger i = 0; i < dataLen; ++i) {
		[sb appendFormat:@"%02lx", (unsigned long)rawBytes[i]];
	}
	
	return sb;
}


@end
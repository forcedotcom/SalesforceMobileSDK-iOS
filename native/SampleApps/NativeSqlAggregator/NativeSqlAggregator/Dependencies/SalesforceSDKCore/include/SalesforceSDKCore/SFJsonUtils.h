/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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


/**
 This class helps decouple framework code from the underlying JSON implementation.
 */
@interface SFJsonUtils : NSObject


/**
 * Creates the JSON representation of an object.
 * @param object The object to JSON-ify
 * @return a JSON string representation of an Objective-C object
 */
+ (NSString*)JSONRepresentation:(id)object;

/**
 * Creates the JSON-as-NSData representation of an object.
 * @param obj The object to JSON-ify.
 * @return A JSON string in NSData format, UTF8 encoded.
 */
+(NSData*)JSONDataRepresentation:(id)obj;


/**
 * Creates an object from a string of JSON data.
 * @param jsonString A JSON object string.
 * @return An Objective-C object such as an NSDictionary or NSArray.
 */
+ (id)objectFromJSONString:(NSString *)jsonString;

/**
 * Creates an object from a JSON-as-NSData object.
 * @param jsonData JSON data in an NSData wrapper (UTF8 encoding assumed).
 * @return An Objective-C object such as an NSDictionary or NSArray.
 */
+ (id)objectFromJSONData:(NSData *)jsonData;



/**
 Pull a value from the json-derived object by path ("." delimited)
 */
+ (id)projectIntoJson:(NSDictionary *)jsonObj path:(NSString *)path;

@end

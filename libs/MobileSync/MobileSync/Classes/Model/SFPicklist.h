/*
 SFPicklist.h
 MobileSync
 
 Created by Keith Siilats on 4/23/2020.
 
 Copyright (c) 2018-present, bytelogics.com, inc. All rights reserved.
 
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

@class SFPicklistField;
@class SFPicklistValue;

/**
 * Represents the Picklist of a Salesforce object.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_Picklist.htm
 */
NS_SWIFT_NAME(Picklist)
@interface SFPicklist : NSObject

@property (nonatomic, strong, readonly, nullable) NSDictionary<NSString *, SFPicklistField *> *fields;
@property (nonatomic, strong, readonly, nullable) NSDictionary *rawData;

/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end

/**
 * Represents a record Picklist fields.
 *
 **/
@interface SFPicklistField : NSObject

@property (nonatomic, strong, readonly, nullable) SFPicklistValue *defaultValue;
@property (nonatomic, strong, readonly, nullable) NSArray<SFPicklistValue *> *values;
@property (nonatomic, strong, readonly, nullable) NSDictionary<NSString *, NSNumber *> *controllerValues;

/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end

/**
 * Represents a record picklist value.
 *
 */
@interface SFPicklistValue : NSObject

@property (nonatomic, strong, readonly, nullable) NSString *label;
@property (nonatomic, strong, readonly, nullable) NSString *value;
@property (nonatomic, strong, readonly, nullable) NSDictionary *attributes;
@property (nonatomic, strong, readonly, nullable) NSArray<NSNumber *> *validFor;


/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end

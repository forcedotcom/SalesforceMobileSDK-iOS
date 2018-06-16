/*
 SFLayout.h
 SmartSync
 
 Created by Bharath Hariharan on 5/17/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

@class SFLayoutSection;
@class SFRow;
@class SFItem;

/**
 * Represents the layout of a Salesforce object.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout.htm
 */
@interface SFLayout : NSObject

@property (nonatomic, strong, readonly, nullable) NSString *id;
@property (nonatomic, strong, readonly, nonnull) NSString *layoutType;
@property (nonatomic, strong, readonly, nullable) NSString *mode;
@property (nonatomic, strong, readonly, nullable) NSArray<SFLayoutSection *> *sections;
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
 * Represents a record layout section.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout_section.htm#ui_api_responses_record_layout_section
 */
@interface SFLayoutSection : NSObject

@property (nonatomic, readonly, assign) BOOL collapsible;
@property (nonatomic, strong, readonly, nullable) NSNumber *columns;
@property (nonatomic, strong, readonly, nullable) NSString *heading;
@property (nonatomic, strong, readonly, nullable) NSString *id;
@property (nonatomic, strong, readonly, nullable) NSArray<SFRow *> *layoutRows;
@property (nonatomic, strong, readonly, nullable) NSNumber *rows;
@property (nonatomic, readonly, assign) BOOL userHeading;

/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end

/**
 * Represents a record layout row.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout_row.htm#ui_api_responses_record_layout_row
 */
@interface SFRow : NSObject

@property (nonatomic, strong, readonly, nullable) NSArray<SFItem *> *layoutItems;

/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end

/**
 * Represents a record layout item.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout_item.htm#ui_api_responses_record_layout_item
 */
@interface SFItem : NSObject

@property (nonatomic, readonly, assign) BOOL editableForNew;
@property (nonatomic, readonly, assign) BOOL editableForUpdate;
@property (nonatomic, strong, readonly, nullable) NSString *label;
@property (nonatomic, strong, readonly, nullable) NSDictionary *layoutComponents;
@property (nonatomic, strong, readonly, nullable) NSString *lookupIdApiName;
@property (nonatomic, readonly, assign) BOOL required;
@property (nonatomic, readonly, assign) BOOL sortable;

/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end

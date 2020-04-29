/*
 SFPicklist.m
 MobileSync
 
 Created by Keith Siilats on 4/23/2020.
 
 Copyright (c) 2018-present, Bytelogics.com, inc. All rights reserved.
 
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

#import "SFPicklist.h"

static NSString * const kSFFieldValues = @"picklistFieldValues";
static NSString * const kSFDefaultValue = @"defaultValue";
static NSString * const kSFValues = @"values";
static NSString * const kSFControllerValues = @"controllerValues";
static NSString * const kSFLabel = @"label";
static NSString * const kSFValue = @"value";
static NSString * const kSFAttributes = @"attributes";
static NSString * const kSFValidFor = @"validFor";

@interface SFPicklist ()

@property (nonatomic, strong, readwrite) NSDictionary<NSString *, SFPicklistField *> *fields;
@property (nonatomic, strong, readwrite) NSDictionary *rawData;

@end

@implementation SFPicklist

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFPicklist *picklist = nil;
    if (data) {
        picklist = [[SFPicklist alloc] init];
        picklist.rawData = data;
        NSDictionary *sections = data[kSFFieldValues];
        NSMutableDictionary<NSString *, SFPicklistField *> *extractedSections = nil;
        if (sections) {
            extractedSections = [[NSMutableDictionary alloc] init];
            for (id key in sections) {
                NSDictionary *section = [sections objectForKey:key];
                if (section) {
                    [extractedSections setObject:[SFPicklistField fromJSON:section] forKey:key];
                }
            }
        }
        picklist.fields = extractedSections;
    }
    return picklist;
}

@end

@interface SFPicklistField ()

@property (nonatomic, strong, readwrite) SFPicklistValue *defaultValue;
@property (nonatomic, strong, readwrite) NSArray<SFPicklistValue *> *values;
@property (nonatomic, strong, readwrite) NSDictionary<NSString *, NSNumber *> *controllerValues;

@end

@implementation SFPicklistField

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFPicklistField *field = nil;
    if (data) {
        field = [[SFPicklistField alloc] init];
        field.defaultValue = data[kSFDefaultValue];
        field.controllerValues = data[kSFControllerValues];
        NSArray *rows = data[kSFValues];
        NSMutableArray<SFPicklistValue *> *extractedRows = nil;
        if (rows) {
            extractedRows = [[NSMutableArray alloc] init];
            for (int i = 0; i < rows.count; i++) {
                NSDictionary *row = rows[i];
                if (row) {
                    [extractedRows addObject:[SFPicklistValue fromJSON:row]];
                }
            }
        }
        field.values = extractedRows;
    }
    return field;
}

@end

@interface SFPicklistValue ()
@property (nonatomic, strong, readwrite) NSString *label;
@property (nonatomic, strong, readwrite) NSString *value;
@property (nonatomic, strong, readwrite) NSDictionary *attributes;
@property (nonatomic, strong, readwrite) NSArray<NSNumber *> *validFor;

@end
@implementation SFPicklistValue

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFPicklistValue *item = nil;
    if (data) {
        item = [[SFPicklistValue alloc] init];
        item.label = data[kSFLabel];
        item.value = data[kSFValue];
        item.attributes = data[kSFAttributes];
        item.validFor = data[kSFValidFor];
    }
    return item;
}

@end

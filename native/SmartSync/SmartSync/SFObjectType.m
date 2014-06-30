/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFObjectType+Internal.h"

static NSString * const SF_OBJECTYPE_KEYPREFIX_FIELD = @"keyPrefix";
static NSString * const SF_OBJECTYPE_NAME_FIELD = @"name";
static NSString * const SF_OBJECTYPE_LABEL_FIELD = @"label";
static NSString * const SF_OBJECTYPE_LABELPLURAL_FIELD = @"labelPlural";
static NSString * const SF_OBJECTYPE_FIELDS_FIELD = @"fields";
static NSString * const SF_OBJECTYPE_UPDATEABLE_FIELD = @"updateable";
static NSString * const SF_OBJECTYPE_QUERYABLE_FIELD = @"queryable";
static NSString * const SF_OBJECTYPE_LAYOUTABLE_FIELD = @"layoutable";
static NSString * const SF_OBJECTYPE_SEARCHABLE_FIELD = @"searchable";
static NSString * const SF_OBJECTYPE_FEEDENABLED_FIELD = @"feedEnabled";
static NSString * const SF_OBJECTYPE_CREATABLE_FIELD = @"createable";
static NSString * const SF_OBJECTYPE_HIDDEN_FIELD = @"deprecatedAndHidden";
static NSString * const SF_OBJECTTYPE_NAMEFIELD_FIELD = @"nameField";
static NSString * const SF_OBJECTTYPE_RAWDATA_FIELD = @"rawData";
static NSString * const SF_OBJECTTPE_NETWORK_ID_FIELD = @"NetworkId";
static NSString * const SF_OBJECTTPE_NETWORK__SCOPE_FIELD = @"NetworkScope";

@implementation SFObjectType

- (id)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        self.name = name;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dataDiction {
    self = [super init];
    if (self) {
        self.rawData = dataDiction;
        [self configureDataWithDictionary:dataDiction];
    }
    return self;
}

- (void)configureDataWithDictionary:(NSDictionary *)dataDiction {
    self.rawData = dataDiction;
    self.keyPrefix = dataDiction[SF_OBJECTYPE_KEYPREFIX_FIELD];
    self.name = dataDiction[SF_OBJECTYPE_NAME_FIELD];
    self.label = dataDiction[SF_OBJECTYPE_LABEL_FIELD];
    self.labelPlural = dataDiction[SF_OBJECTYPE_LABELPLURAL_FIELD];
    if (nil == self.label) {
        self.label = self.name;
    }
    if (nil == self.labelPlural) {
        self.labelPlural = self.label;
    }
}

- (NSArray *)fields {
    NSArray *fields = self.rawData[SF_OBJECTYPE_FIELDS_FIELD];
    return fields;
}

- (NSString *)nameField {
    if (_nameField) {
        return _nameField;
    }
    NSArray *dataFields = self.rawData[SF_OBJECTYPE_FIELDS_FIELD];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"nameField = YES"];
    NSArray *nameFields = [dataFields filteredArrayUsingPredicate:predicate];
    if (nameFields && nameFields.count > 0) {
        _nameField = [nameFields[0] valueForKey:SF_OBJECTYPE_NAME_FIELD];
    }
    return _nameField;
}

- (NSString *)description {
    return self.name;
}

- (NSString *)networkField {
    if (nil != self.networkField) {
        return self.networkField;
    }
    NSArray *dataFields = self.rawData[SF_OBJECTYPE_FIELDS_FIELD];
    if (nil != dataFields) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"nameField = YES"];
        NSArray *nameFields = [dataFields filteredArrayUsingPredicate:predicate];
        if (nameFields && nameFields.count > 0) {
            for (int i = 0; i < nameFields.count; i++) {
                NSString *nameField = nameFields[i];
                if (nil != nameField && ([nameField isEqualToString:SF_OBJECTTPE_NETWORK_ID_FIELD]
                            || [nameField isEqualToString:SF_OBJECTTPE_NETWORK__SCOPE_FIELD])) {
                    self.networkField = nameField;
                }
            }
        }
    }
    return self.networkField;
}

- (BOOL)isSearchable {
    BOOL flag = (self.rawData &&
                 ![self.rawData[SF_OBJECTYPE_HIDDEN_FIELD] boolValue] &&
                 [self.rawData[SF_OBJECTYPE_SEARCHABLE_FIELD] boolValue]);
    return flag;
}

- (BOOL)isLayoutable {
    BOOL flag = (self.rawData &&
                 ![self.rawData[SF_OBJECTYPE_HIDDEN_FIELD] boolValue] &&
                 [self.rawData[SF_OBJECTYPE_LAYOUTABLE_FIELD] boolValue]);
    return flag;
}

#pragma mark - isEqual Methods

- (NSUInteger)hash {
    NSUInteger result = [self.name hash];
    result ^= [self.rawData hash] + result * 37;
    return result;
}

- (BOOL)isEqual:(id)object {
    if (nil == object || ![object isKindOfClass:[SFObjectType class]]) {
        return NO;
    }
    SFObjectType *otherObj = (SFObjectType *)object;
    if (self.name != otherObj.name && ![self.name isEqualToString:otherObj.name]) {
        return NO;
    }
    if (self.rawData != otherObj.rawData &&
        ![self.rawData isEqual:otherObj.rawData]) {
        return NO;
    }
    return YES;
}

#pragma mark - NSCoding Protocol

- (void)encodeObject:(id)object forKey:(NSString *)key encoder:(NSCoder *)encoder {
    if (object && key && encoder) {
        [encoder encodeObject:object forKey:key];
    }
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [self encodeObject:self.keyPrefix forKey:SF_OBJECTYPE_KEYPREFIX_FIELD encoder:encoder];
    [self encodeObject:self.name forKey:SF_OBJECTYPE_NAME_FIELD encoder:encoder];
    [self encodeObject:self.label forKey:SF_OBJECTYPE_LABEL_FIELD encoder:encoder];
    [self encodeObject:self.labelPlural forKey:SF_OBJECTYPE_LABELPLURAL_FIELD encoder:encoder];
    [self encodeObject:self.nameField forKey:SF_OBJECTTYPE_NAMEFIELD_FIELD encoder:encoder];
    [self encodeObject:self.rawData forKey:SF_OBJECTTYPE_RAWDATA_FIELD encoder:encoder];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [self init];
    if (self) {
        self.keyPrefix = [decoder decodeObjectForKey:SF_OBJECTYPE_KEYPREFIX_FIELD];
        self.name = [decoder decodeObjectForKey:SF_OBJECTYPE_NAME_FIELD];
        self.label = [decoder decodeObjectForKey:SF_OBJECTYPE_LABEL_FIELD];
        self.labelPlural = [decoder decodeObjectForKey:SF_OBJECTYPE_LABELPLURAL_FIELD];
        self.nameField = [decoder decodeObjectForKey:SF_OBJECTTYPE_NAMEFIELD_FIELD];
        self.rawData = [decoder decodeObjectForKey:SF_OBJECTTYPE_RAWDATA_FIELD];
    }
    return self;
}

@end

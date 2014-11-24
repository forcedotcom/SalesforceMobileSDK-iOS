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
#import "SFSmartSyncConstants.h"

@implementation SFObjectType

@synthesize rawData;

- (id)initWithDictionary:(NSDictionary *)data {
    self = [super initWithDictionary:data];
    if (self) {
        [self configureDataWithDictionary:data];
    }
    return self;
}

- (void)configureDataWithDictionary:(NSDictionary *)dataDiction {
    self.keyPrefix = dataDiction[kKeyPrefixField];
    self.name = dataDiction[kNameField];
    self.label = dataDiction[kLabelField];
    self.labelPlural = dataDiction[kLabelPluralField];
    if (nil == self.label) {
        self.label = self.name;
    }
    if (nil == self.labelPlural) {
        self.labelPlural = self.label;
    }
}

- (NSArray *)fields {
    NSArray *fields = self.rawData[kFieldsField];
    return fields;
}

- (NSString *)nameField {
    if (_nameField) {
        return _nameField;
    }
    NSArray *dataFields = self.rawData[kFieldsField];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"nameField = YES"];
    NSArray *nameFields = [dataFields filteredArrayUsingPredicate:predicate];
    if (nameFields && nameFields.count > 0) {
        _nameField = [nameFields[0] valueForKey:kNameField];
    }
    return _nameField;
}

- (NSString *)description {
    return self.name;
}

- (BOOL)isSearchable {
    BOOL flag = (self.rawData &&
                 ![self.rawData[kHiddenField] boolValue] &&
                 [self.rawData[kSearchableField] boolValue]);
    return flag;
}

- (BOOL)isLayoutable {
    BOOL flag = (self.rawData &&
                 ![self.rawData[kHiddenField] boolValue] &&
                 [self.rawData[kLayoutableField] boolValue]);
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
    [self encodeObject:self.keyPrefix forKey:kKeyPrefixField encoder:encoder];
    [self encodeObject:self.name forKey:kNameField encoder:encoder];
    [self encodeObject:self.label forKey:kLabelField encoder:encoder];
    [self encodeObject:self.labelPlural forKey:kLabelPluralField encoder:encoder];
    [self encodeObject:self.nameField forKey:kNameFieldField encoder:encoder];
    [self encodeObject:self.rawData forKey:kRawData encoder:encoder];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [self init];
    if (self) {
        self.keyPrefix = [decoder decodeObjectForKey:kKeyPrefixField];
        self.name = [decoder decodeObjectForKey:kNameField];
        self.label = [decoder decodeObjectForKey:kLabelField];
        self.labelPlural = [decoder decodeObjectForKey:kLabelPluralField];
        self.nameField = [decoder decodeObjectForKey:kNameFieldField];
        self.rawData = [decoder decodeObjectForKey:kRawData];
    }
    return self;
}

@end

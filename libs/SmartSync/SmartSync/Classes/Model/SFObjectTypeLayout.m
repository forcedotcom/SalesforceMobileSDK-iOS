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

#import "SFObjectTypeLayout+Internal.h"
#import "SFSmartSyncPersistableObject+Internal.h"
#import "SFSmartSyncConstants.h"

@implementation SFObjectTypeLayout

- (id)initWithDictionary:(NSDictionary *)data {
    self = [super initWithDictionary:data];
    if (self) {
        [self configureDataWithDictionary:data];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)data forObjectType:(NSString *)theObjectType {
    self = [super initWithDictionary:data forObjectType:theObjectType];
    if (self) {
        [self configureDataWithDictionary:data];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, %@, %@, rawData:[%@]", self.objectType, [self.limit stringValue], self.columns, self.rawData];
}

- (void)configureDataWithDictionary:(NSDictionary *)dataDiction {
    if (nil == self.rawData) {
        return;
    }
    self.limit = dataDiction[kLayoutLimitsField];
    self.columns = dataDiction[kLayoutColumnsField];
}

#pragma mark - Class Method

+ (NSString *)parseColumnName:(NSString *)columnName {
    if (nil == columnName) {
        return nil;
    }
    NSInteger checkStartPos = [columnName rangeOfString:@"("].location;
    if (checkStartPos == NSNotFound) {
        return columnName;
    }
    NSInteger checkStopPos = [columnName rangeOfString:@")"].location;
    if (checkStopPos == NSNotFound) {
        return columnName;
    }
    columnName = [columnName substringWithRange:NSMakeRange(checkStartPos + 1, checkStopPos - checkStartPos - 1)];
    return columnName;
}

+ (BOOL)isMatchColumns:(NSArray *)sourceColumnNames target:(NSArray *)targetColumnNames {
    if (sourceColumnNames == nil || targetColumnNames == nil) {
        return NO;
    }
    if (targetColumnNames.count != sourceColumnNames.count) {
        return  NO;
    }
    for (NSUInteger idx = 0; idx < sourceColumnNames.count; idx++) {
        NSString *sourceColumn = [[self class] parseColumnName:sourceColumnNames[idx]];
        NSString *targetColumn = [[self class] parseColumnName:targetColumnNames[idx]];
        if (![sourceColumn isEqualToString:targetColumn]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - isEqual Methods

- (NSUInteger)hash {
    NSUInteger result = [self.objectType hash];
    return result;
}

- (BOOL)isEqual:(id)object {
    if (nil == object || ![object isKindOfClass:[SFObjectTypeLayout class]]) {
        return NO;
    }
    SFObjectTypeLayout *otherObj = (SFObjectTypeLayout *)object;
    if (self.objectType != otherObj.objectType && ![self.objectType isEqualToString:otherObj.objectType]) {
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
    [self encodeObject:self.objectType forKey:kLayoutObjectTypeField encoder:encoder];
    [self encodeObject:self.rawData forKey:kRawData encoder:encoder];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [self init];
    if (self) {
        self.objectType = [decoder decodeObjectForKey:kLayoutObjectTypeField];
        self.rawData = [decoder decodeObjectForKey:kRawData];
        [self configureDataWithDictionary:self.rawData];
    }
    return self;
}

@end

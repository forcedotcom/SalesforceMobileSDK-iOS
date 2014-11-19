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

#import "SFObject+Internal.h"
#import "SFSmartSyncPersistableObject+Internal.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSmartSyncConstants.h"

@implementation SFObject

#pragma mark - Init Methods

- (id)initWithDictionary:(NSDictionary *)data {
    self = [super initWithDictionary:data];
    if (self) {
        [self configureDataWithDictionary:data];
    }
    return self;
}

- (void)configureDataWithDictionary:(NSDictionary *)dataDiction {
    self.objectId = dataDiction[kId];
    if (!self.objectId) {
        self.objectId = dataDiction[[kId lowercaseString]];
        self.objectType = dataDiction[kType];
        self.name = dataDiction[[kName lowercaseString]];
    } else {
        self.name = dataDiction[kName];
        NSString *type = [SFSmartSyncObjectUtils formatValue:[dataDiction valueForKeyPath:kObjectTypeField]];
        if ([type isEqualToString:kRecentlyViewed]) {
            type = [SFSmartSyncObjectUtils formatValue:dataDiction[kType]];
        }
        self.objectType = type;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"name:[%@], objectId:[%@], type:[%@], rawData:[%@]", self.name, self.objectId, self.objectType, self.rawData];
}

#pragma mark - isEqual Methods

- (NSUInteger)hash {
    NSUInteger result = [self.objectId hash];
    result ^= [self.rawData hash] + result * 37;
    
    return result;
}

- (BOOL)isEqual:(id)object {
    if (nil == object || ![object isKindOfClass:[SFObject class]]) {
        return NO;
    }
    SFObject *otherObj = (SFObject *)object;
    if (self.objectId != otherObj.objectId && ![self.objectId isEqualToString:otherObj.objectId]) {
        return NO;
    }
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
    [self encodeObject:self.rawData forKey:kRawData encoder:encoder];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [self init];
    if (self) {
        self.rawData = [decoder decodeObjectForKey:kRawData];
        [self configureDataWithDictionary:self.rawData];
    }
    return self;
}
@end

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

#import "SObjectData+Internal.h"
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>

@implementation SObjectData

- (id)initWithSoupDict:(NSDictionary *)soupDict {
    self = [self init];
    if (self) {
        if (soupDict != nil) {
            for (NSString *fieldName in [soupDict allKeys]) {
                [self updateSoupForFieldName:fieldName fieldValue:soupDict[fieldName]];
            }
        }
    }
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
        self.soupDict = @{ };
        for (NSString *fieldName in [[self class] dataSpec].fieldNames) {
            [self updateSoupForFieldName:fieldName fieldValue:[NSNull null]];
        }
        [self updateSoupForFieldName:@"attributes" fieldValue:@{ @"type": [[self class] dataSpec].objectType }];
    }
    return self;
}

- (void)updateSoupForFieldName:(NSString *)fieldName fieldValue:(id)fieldValue  {
    NSMutableDictionary *mutableSoup = [self.soupDict mutableCopy];
    if (fieldValue == nil)
        fieldValue = [NSNull null];
    
    mutableSoup[fieldName] = fieldValue;
    self.soupDict = mutableSoup;
}

- (id)fieldValueForFieldName:(NSString *)fieldName {
    return [self nonNullFieldValue:fieldName];
}

- (id)nonNullFieldValue:(NSString *)fieldName {
    return [self.soupDict nonNullObjectForKey:fieldName];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p> %@", [self class], self, self.soupDict];
}

// dataSpec is abstract.
+ (SObjectDataSpec *)dataSpec {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

@end

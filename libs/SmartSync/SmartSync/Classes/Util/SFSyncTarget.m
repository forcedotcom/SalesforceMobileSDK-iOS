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

#import "SFSyncTarget.h"
#import "SFSmartSyncConstants.h"
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

@implementation SFSyncTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (dict == nil) return nil;
    
    self = [super init];
    if (self) {
        NSString *idFieldName = dict[kSFSyncTargetIdFieldNameKey];
        NSString *modificationDateFieldName = dict[kSFSyncTargetModificationDateFieldNameKey];
        self.idFieldName = (idFieldName.length > 0 ? idFieldName : kId);
        self.modificationDateFieldName = (modificationDateFieldName.length > 0 ? modificationDateFieldName : kLastModifiedDate);
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.idFieldName = kId;
        self.modificationDateFieldName = kLastModifiedDate;
    }
    return self;
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kSFSyncTargetIdFieldNameKey] = self.idFieldName;
    dict[kSFSyncTargetModificationDateFieldNameKey] = self.modificationDateFieldName;
    return dict;
}

@end
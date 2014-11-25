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

NSString * const kSFSyncTargetQueryType = @"type";
NSString * const kSFSyncTargetQuery = @"query";
NSString * const kSFSyncTargetObjectType = @"sobjectType";
NSString * const kSFSyncTargetFieldlist = @"fieldlist";

// query types
NSString * const kSFSyncTargetQueryTypeMru = @"mru";
NSString * const kSFSyncTargetQueryTypeSoql = @"soql";
NSString * const kSFSyncTargetQueryTypeSosl = @"sosl";

@interface SFSyncTarget ()

@property (nonatomic, readwrite)            SFSyncTargetQueryType queryType;
@property (nonatomic, strong, readwrite) NSString* query;
@property (nonatomic, strong, readwrite) NSString* objectType;
@property (nonatomic, strong, readwrite) NSArray*  fieldlist;

// true when initiazed from empty dictionary
@property (nonatomic) BOOL isUndefined;

@end

@implementation SFSyncTarget

#pragma mark - Factory methods

+ (SFSyncTarget*) newSyncTargetForMRUSyncDown:(NSString*)objectType fieldlist:(NSArray*)fieldlist {
    SFSyncTarget* syncTarget = [[SFSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeMru;
    syncTarget.objectType = objectType;
    syncTarget.fieldlist = fieldlist;
    syncTarget.isUndefined = NO;
    return syncTarget;
}

+ (SFSyncTarget*) newSyncTargetForSOSLSyncDown:(NSString*)query {
    SFSyncTarget* syncTarget = [[SFSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeSosl;
    syncTarget.query = query;
    syncTarget.isUndefined = NO;
    return syncTarget;
}

+ (SFSyncTarget*) newSyncTargetForSOQLSyncDown:(NSString*)query {
    SFSyncTarget* syncTarget = [[SFSyncTarget alloc] init];
    syncTarget.queryType = SFSyncTargetQueryTypeSoql;
    syncTarget.query = query;
    syncTarget.isUndefined = NO;
    return syncTarget;
}


#pragma mark - From/to dictionary

+ (SFSyncTarget*) newFromDict:(NSDictionary*)dict {
    SFSyncTarget* syncTarget = [[SFSyncTarget alloc] init];
    if (syncTarget) {
        if (dict == nil || [dict count] == 0) {
            syncTarget.isUndefined = YES;
        }
        else {
            syncTarget.isUndefined = NO;
            syncTarget.queryType = [SFSyncTarget queryTypeFromString:dict[kSFSyncTargetQueryType]];
            switch (syncTarget.queryType) {
                case SFSyncTargetQueryTypeMru:
                    syncTarget.objectType = dict[kSFSyncTargetObjectType];
                    syncTarget.fieldlist = dict[kSFSyncTargetFieldlist];
                    break;
                case SFSyncTargetQueryTypeSosl:
                    syncTarget.query = dict[kSFSyncTargetQuery];
                    break;
                case SFSyncTargetQueryTypeSoql:
                    syncTarget.query = dict[kSFSyncTargetQuery];
                    break;
            }
        }
    }
    
    return syncTarget;
}

- (NSDictionary*) asDict {
    NSDictionary* dict;

    if (self.isUndefined) {
        dict = @{};
    }
    else {
        switch (self.queryType) {
            case SFSyncTargetQueryTypeSoql:
                dict = @{
                         kSFSyncTargetQueryType: [SFSyncTarget queryTypeToString:self.queryType],
                         kSFSyncTargetQuery: self.query
                         };
                break;
            case SFSyncTargetQueryTypeSosl:
                dict = @{
                         kSFSyncTargetQueryType: [SFSyncTarget queryTypeToString:self.queryType],
                         kSFSyncTargetQuery: self.query
                         };
                break;
            case SFSyncTargetQueryTypeMru:
                dict = @{
                         kSFSyncTargetQueryType: [SFSyncTarget queryTypeToString:self.queryType],
                         kSFSyncTargetObjectType: self.objectType,
                         kSFSyncTargetFieldlist: self.fieldlist
                         };
                break;
        }
    }

    return dict;
}

#pragma mark - string to/from enum for query type

+ (SFSyncTargetQueryType) queryTypeFromString:(NSString*)queryType {
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeSoql]) {
        return SFSyncTargetQueryTypeSoql;
    }
    if ([queryType isEqualToString:kSFSyncTargetQueryTypeMru]) {
        return SFSyncTargetQueryTypeMru;
    }
    // Must be SOSL
    return SFSyncTargetQueryTypeSosl;
}

+ (NSString*) queryTypeToString:(SFSyncTargetQueryType)queryType {
    switch (queryType) {
        case SFSyncTargetQueryTypeMru:  return kSFSyncTargetQueryTypeMru;
        case SFSyncTargetQueryTypeSosl: return kSFSyncTargetQueryTypeSosl;
        case SFSyncTargetQueryTypeSoql: return kSFSyncTargetQueryTypeSoql;
    }
}

@end

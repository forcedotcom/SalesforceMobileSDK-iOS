/*
Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKPrimingRecordsResponse.h"
#import "NSDictionary+SFAdditions.h"
#import "SFFormatUtils.h"

@implementation SFSDKPrimingRecordsResponse

-(instancetype)initWith:(NSDictionary *)dict {
    if (self=[super init]) {
        //Priming records
        NSMutableDictionary* apiNameToTypeToPrimingRecords = [NSMutableDictionary new];
        NSDictionary* apiNameToTypeToPrimingRecordsRaw = dict[@"primingRecords"];
        for (NSString* apiName in apiNameToTypeToPrimingRecordsRaw) {
            NSMutableDictionary* typeToPrimingRecords =[NSMutableDictionary new];
            NSDictionary* typeToPrimingRecordsRaw = apiNameToTypeToPrimingRecordsRaw[apiName];
            for (NSString* recordType in typeToPrimingRecordsRaw) {
                NSMutableArray* primingRecords = [NSMutableArray new];
                NSArray* primingRecordsRaw = typeToPrimingRecordsRaw[recordType];
                for (NSDictionary* primingRecordRaw in primingRecordsRaw) {
                    [primingRecords addObject:[[SFSDKPrimingRecord alloc] initWith:primingRecordRaw]];
                }
                typeToPrimingRecords[recordType] = primingRecords;
            }
            apiNameToTypeToPrimingRecords[apiName] = typeToPrimingRecords;
        }
        _primingRecords = apiNameToTypeToPrimingRecords;
        
        // Relay token
        _relayToken = [dict sfsdk_nonNullObjectForKey:@"relayToken"];

        // Rule errors
        NSMutableArray* ruleErrors = [NSMutableArray new];
        NSArray* ruleErrorsRaw = dict[@"ruleErrors"];
        for (NSDictionary* ruleErrorRaw in ruleErrorsRaw) {
            [ruleErrors addObject:[[SFSDKPrimingRuleError alloc] initWith:ruleErrorRaw]];
        }
        _ruleErrors = ruleErrors;
        
        // Stats
        _stats = [[SFSDKPrimingStats alloc] initWith:dict[@"stats"]];
    }
    return self;
}

@end

@implementation SFSDKPrimingRecord

-(instancetype)initWith:(NSDictionary *)dict {
    if (self=[super init]) {
        _dict = dict;
        _objectId = dict[@"id"];
        _systemModstamp = [SFFormatUtils getDateFromIsoDateString:dict[@"systemModstamp"]];
    }
    return self;
}

- (NSString*) description {
    return [self.dict description];
}

@end

@implementation SFSDKPrimingRuleError

-(instancetype)initWith:(NSDictionary *)dict {
    if (self=[super init]) {
        _dict = dict;
        _ruleId = dict[@"ruleId"];
    }
    return self;
}

- (NSString*) description {
    return [self.dict description];
}

@end


@implementation SFSDKPrimingStats

-(instancetype)initWith:(NSDictionary *)dict {
    if (self=[super init]) {
        _dict = dict;
        _ruleCountTotal = [dict[@"ruleCountTotal"] integerValue];
        _recordCountTotal = [dict[@"recordCountTotal"] integerValue];
        _ruleCountServed = [dict[@"ruleCountServed"] integerValue];
        _recordCountServed = [dict[@"recordCountServed"] integerValue];;
    }
    return self;
}

- (NSString*) description {
    return [self.dict description];
}


@end

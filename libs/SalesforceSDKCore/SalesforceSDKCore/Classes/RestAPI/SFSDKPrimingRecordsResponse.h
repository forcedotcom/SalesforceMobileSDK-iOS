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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(PrimingRecord)
@interface SFSDKPrimingRecord : NSObject
@property (nonatomic,readonly) NSDictionary* dict;
@property (nonatomic,readonly) NSString* objectId;
@property (nonatomic,readonly) NSDate* systemModstamp;
-(instancetype)initWith:(NSDictionary *)dict;
@end

NS_SWIFT_NAME(PrimingRuleError)
@interface SFSDKPrimingRuleError : NSObject
@property (nonatomic,readonly) NSDictionary* dict;
@property (nonatomic,readonly) NSString* ruleId;
-(instancetype)initWith:(NSDictionary *)dict;
@end

NS_SWIFT_NAME(PrimingStats)
@interface SFSDKPrimingStats : NSObject
@property (nonatomic,readonly) NSDictionary* dict;
@property (nonatomic,readonly) NSUInteger ruleCountTotal;
@property (nonatomic,readonly) NSUInteger recordCountTotal;
@property (nonatomic,readonly) NSUInteger ruleCountServed;
@property (nonatomic,readonly) NSUInteger recordCountServed;
-(instancetype)initWith:(NSDictionary *)dict;
@end

NS_SWIFT_NAME(PrimingRecordsResponse)
@interface SFSDKPrimingRecordsResponse : NSObject
@property (nonatomic,readonly) NSDictionary<NSString*, NSDictionary<NSString*, NSArray<SFSDKPrimingRecord*>*>*>* primingRecords;
@property (nonatomic,readonly,nullable) NSString *relayToken;
@property (nonatomic,readonly) NSArray<SFSDKPrimingRuleError*>* ruleErrors;
@property (nonatomic,readonly) SFSDKPrimingStats * stats;
-(instancetype)initWith:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END

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

#import <Foundation/Foundation.h>

typedef enum {
  SFSyncTargetQueryTypeMru,
  SFSyncTargetQueryTypeSosl,
  SFSyncTargetQueryTypeSoql
} SFSyncTargetQueryType;

extern NSString * const kSFSyncTargetQueryType;
extern NSString * const kSFSyncTargetQuery;
extern NSString * const kSFSyncTargetObjectType;
extern NSString * const kSFSyncTargetFieldlist;

@interface SFSyncTarget : NSObject

@property (nonatomic, readonly)         SFSyncTargetQueryType queryType;
@property (nonatomic, strong, readonly) NSString* query;
@property (nonatomic, strong, readonly) NSString* objectType;
@property (nonatomic, strong, readonly) NSArray*  fieldlist;

/** Factory methods
 */
+ (SFSyncTarget*) newSyncTargetForSOQLSyncDown:(NSString*)query;
+ (SFSyncTarget*) newSyncTargetForSOSLSyncDown:(NSString*)query;
+ (SFSyncTarget*) newSyncTargetForMRUSyncDown:(NSString*)objectType fieldlist:(NSArray*)fieldlist;

/** Methods to translate to/from dictionary
 */
+ (SFSyncTarget*) newFromDict:(NSDictionary *)dict;
- (NSDictionary*) asDict;

/** Enum to/from string helper methods
 */
+ (SFSyncTargetQueryType) queryTypeFromString:(NSString*)queryType;
+ (NSString*) queryTypeToString:(SFSyncTargetQueryType)queryType;

@end

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

#import "SFSyncOptions.h"

NSString * const kSFSyncOptionsFieldlist = @"fieldlist";
NSString * const kSFSyncOptionsMergeMode = @"mergeMode";

@interface SFSyncOptions ()

@property (nonatomic, strong, readwrite) NSArray*  fieldlist;
@property (nonatomic, readwrite)         SFSyncStateMergeMode mergeMode;

@end

@implementation SFSyncOptions

#pragma mark - Factory methods

+ (SFSyncOptions*) newSyncOptionsForSyncUp:(NSArray*)fieldlist {
    return [SFSyncOptions newSyncOptionsForSyncUp:fieldlist mergeMode:SFSyncStateMergeModeOverwrite];
}

+ (SFSyncOptions*) newSyncOptionsForSyncUp:(NSArray*)fieldlist mergeMode:(SFSyncStateMergeMode)mergeMode {
    SFSyncOptions* syncOptions = [[SFSyncOptions alloc] init];
    syncOptions.fieldlist = fieldlist;
    syncOptions.mergeMode = mergeMode;
    return syncOptions;
}

+ (SFSyncOptions*) newSyncOptionsForSyncDown:(SFSyncStateMergeMode)mergeMode {
    SFSyncOptions* syncOptions = [[SFSyncOptions alloc] init];
    syncOptions.mergeMode = mergeMode;
    return syncOptions;
}


#pragma mark - From/to dictionary

+ (SFSyncOptions*) newFromDict:(NSDictionary*)dict {
    SFSyncOptions* syncOptions = nil;
    if (dict != nil && [dict count] != 0) {
        syncOptions = [[SFSyncOptions alloc] init];
        syncOptions.mergeMode = [SFSyncState mergeModeFromString:dict[kSFSyncOptionsMergeMode]];
        syncOptions.fieldlist = dict[kSFSyncOptionsFieldlist];
    }
    return syncOptions;
}

- (NSDictionary*) asDict {
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    if (self.fieldlist) dict[kSFSyncOptionsFieldlist] = self.fieldlist;
    dict[kSFSyncOptionsMergeMode] = [SFSyncState mergeModeToString:self.mergeMode];
    return dict;
}

@end

/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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


#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFSDKStoreConfig.h"
#import "SFSoupIndex.h"
#import "SFSmartStore.h"


static NSString *const kStoreConfigSoups = @"soups";
static NSString *const kStoreConfigSoupName = @"soupName";
static NSString *const kStoreConfigIndexes = @"indexes";

@interface SFSDKStoreConfig ()

@property (nonatomic, nullable) NSArray* soupsConfig;

@end

@implementation SFSDKStoreConfig

- (nullable id)initWithResourceAtPath:(NSString *)path {
    self = [super init];
    if (self) {
        NSDictionary *config = [SFSDKResourceUtils loadConfigFromFile:path];
        self.soupsConfig = config == nil ? nil : config[kStoreConfigSoups];
    }
    return self;
}

- (void)registerSoups:(SFSmartStore *)store {
    if (self.soupsConfig == nil) {
        [SFSDKSmartStoreLogger d:[self class] format:@"No store config available"];
        return;
    }

    for (NSDictionary * soupConfig in self.soupsConfig) {
        NSString *soupName = [soupConfig nonNullObjectForKey:kStoreConfigSoupName];

        // Leaving soup alone if it already exists
        if ([store soupExists:soupName]) {
            [SFSDKSmartStoreLogger d:[self class] format:@"Soup already exists:%@ - skipping", soupName];
            continue;
        }


        NSArray *indexSpecs = [SFSoupIndex asArraySoupIndexes:[soupConfig nonNullObjectForKey:kStoreConfigIndexes]];
        NSError * error = nil;
        [store registerSoup:soupName withIndexSpecs:indexSpecs error:&error];
        if (error) {
            [SFSDKSmartStoreLogger e:[self class] format:@"Error registering soup: %@", soupName, error];
        }
    }
}

- (BOOL)hasSoups {
    return self.soupsConfig != nil && self.soupsConfig.count > 0;
}
@end

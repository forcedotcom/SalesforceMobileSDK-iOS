/*
Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKDatasharingHelper.h"
#import "SFLogger.h"

NSString * const kAppGroupEnabled = @"kAccessGroupEnabled";
NSString * const KAppGroupName = @"KAppGroupName";
NSString * const kDidMigrateToAppGroupsKey = @"kAppDefaultsMigratedToAppGroups";

@implementation SFSDKDatasharingHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFSDKDatasharingHelper *dataSharingHelper = nil;
    dispatch_once(&pred, ^{
        dataSharingHelper = [[self alloc] init];
    });
    return dataSharingHelper;
}

- (NSString *)appGroupName {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    return [standardDefaults stringForKey:KAppGroupName];
}

- (void)setAppGroupName:(NSString *)appGroupName {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject:appGroupName forKey:KAppGroupName];
    [standardDefaults synchronize];
}

- (void)setAppGroupEnabled:(BOOL)appGroupEnabled {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
    [sharedDefaults setBool:appGroupEnabled forKey:kAppGroupEnabled];
    [sharedDefaults synchronize];
    if(appGroupEnabled) {
        [self migrateUserDefaultsToAppContainer:sharedDefaults];
    } else {
        [self migrateFromAppContainerToUserDefaults:sharedDefaults];
    }
}

- (BOOL)appGroupEnabled {
     NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupName];
     return [sharedDefaults boolForKey:kAppGroupEnabled];
}

- (void)migrateUserDefaultsToAppContainer:(NSUserDefaults *)sharedDefaults {
    if([self appGroupEnabled] && ![[NSUserDefaults standardUserDefaults] boolForKey:kDidMigrateToAppGroupsKey]) {
        [[SFLogger defaultLogger] w:[self class] format:@"Ensure that you have enabled app-groups for your app in the entitlements for your app."];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kDidMigrateToAppGroupsKey];
        [self migrateFrom:[NSUserDefaults standardUserDefaults] to:sharedDefaults];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)migrateFromAppContainerToUserDefaults:(NSUserDefaults *)sharedDefaults {
    if(![self appGroupEnabled] && [[NSUserDefaults standardUserDefaults] boolForKey:kDidMigrateToAppGroupsKey]) {
        [[SFLogger defaultLogger] w:[self class] format:@"Ensure that you have not disabled app-groups for your app in the entitlements. Data will not be migrated from app containers if app-groups are disabled"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kDidMigrateToAppGroupsKey];
        [self migrateFrom:sharedDefaults to:[NSUserDefaults standardUserDefaults]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)migrateFrom:(NSUserDefaults *)source to:(NSUserDefaults *)target{
    NSDictionary *sourceDictionary = [source dictionaryRepresentation];
    for(id key in sourceDictionary.allKeys) {
        [target setObject:sourceDictionary[key] forKey:key];
    }
    [target synchronize];
}

@end

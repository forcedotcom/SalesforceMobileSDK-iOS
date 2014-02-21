/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFPreferences.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFDirectoryManager.h"

static NSString * const kPreferencesFileName = @"Preferences.plist";

static NSMutableDictionary *instances = nil;

@interface SFPreferences ()

@property (nonatomic, strong) NSMutableDictionary *attributes;
@property (nonatomic, strong, readwrite) NSString *path;

@end

@implementation SFPreferences

+ (void)initialize {
    if (self == [SFPreferences class]) {
        instances = [NSMutableDictionary dictionary];
    }
}

+ (instancetype)sharedPreferencesForScope:(SFUserAccountScope)scope user:(SFUserAccount*)user {
    SFPreferences *prefs = nil;
    @synchronized (self) {
        NSString *key = SFKeyForUserAndScope(user, scope);
        prefs = instances[key];
        if (nil == prefs) {
            NSString *directory = [[SFDirectoryManager sharedManager] directoryForUser:user scope:scope type:NSLibraryDirectory components:nil];
            NSError *error = nil;
            if ([SFDirectoryManager ensureDirectoryExists:directory error:&error]) {
                prefs = [[SFPreferences alloc] initWithPath:[directory stringByAppendingPathComponent:kPreferencesFileName]];
                instances[key] = prefs;
            } else {
                [[self class] log:SFLogLevelError format:@"Unable to create scoped directory %@: %@", directory, error];
            }
        }
    }
    return prefs;
}

+ (instancetype)globalPreferences {
    return [self sharedPreferencesForScope:SFUserAccountScopeGlobal user:nil];
}

+ (instancetype)currentOrgLevelPreferences {
    return [self sharedPreferencesForScope:SFUserAccountScopeOrg user:[SFUserAccountManager sharedInstance].currentUser];
}

+ (instancetype)currentUserLevelPreferences {
    return [self sharedPreferencesForScope:SFUserAccountScopeUser user:[SFUserAccountManager sharedInstance].currentUser];
}

+ (instancetype)currentCommunityLevelPreferences {
    return [self sharedPreferencesForScope:SFUserAccountScopeCommunity user:[SFUserAccountManager sharedInstance].currentUser];
}

- (id)initWithPath:(NSString*)path {
    self = [super init];
    if (self) {
        self.path = path;
        self.attributes = [[NSMutableDictionary alloc] init];
        
        NSDictionary *loadedAttributes = [NSDictionary dictionaryWithContentsOfFile:self.path];
        if (loadedAttributes) {
            [self.attributes addEntriesFromDictionary:loadedAttributes];
        }
    }
    return self;
}

- (id)objectForKey:(NSString*)key {
    return self.attributes[key];
}

- (void)setObject:(id)object forKey:(NSString*)key {
    self.attributes[key] = object;
}

- (void)removeObjectForKey:(NSString*)key {
    [self.attributes removeObjectForKey:key];
}

- (BOOL)boolForKey:(NSString*)key {
    return [[self objectForKey:key] boolValue];
}

- (void)setBool:(BOOL)value forKey:(NSString*)key {
    [self setObject:@(value) forKey:key];
}

- (NSInteger)integerForKey:(NSString *)key {
    return [[self objectForKey:key] integerValue];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    [self setObject:@(value) forKey:key];
}

- (void)synchronize {
    @synchronized (self) {
        if (![self.attributes writeToFile:self.path atomically:YES]) {
            [self log:SFLogLevelError format:@"Unable to save preferences at %@", self.path];
        }
    }
}

@end

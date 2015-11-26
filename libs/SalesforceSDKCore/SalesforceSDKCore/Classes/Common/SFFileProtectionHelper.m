/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "SFFileProtectionHelper.h"

@interface SFFileProtectionHelper ()

@property (nonatomic, readwrite) NSDictionary *pathsToFileProtection;
@property (nonatomic, strong) dispatch_queue_t pathsToFileProtectionAccessQueue;

@end

@implementation SFFileProtectionHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFFileProtectionHelper *singleton = nil;
    dispatch_once(&pred, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.defaultNSFileProtectionMode = NSFileProtectionComplete;
        self.pathsToFileProtection = [NSDictionary new];
        self.pathsToFileProtectionAccessQueue = dispatch_queue_create("com.salesforce.fileProtectionHelper.pathsToFileProtection", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (NSString*)fileProtectionForPath:(NSString*)path {
    NSString *fileProtection = [SFFileProtectionHelper sharedInstance].pathsToFileProtection[path];
    if (!fileProtection) {
        fileProtection = [SFFileProtectionHelper sharedInstance].defaultNSFileProtectionMode;
    }

    return fileProtection;
}

- (void)addProtection:(NSString *)fileProtection forPath:(NSString *)path {
    dispatch_sync(self.pathsToFileProtectionAccessQueue, ^{
        if (fileProtection && path) {
            NSSet *validFileProtections = [NSSet setWithObjects:NSFileProtectionNone, NSFileProtectionComplete,
                                           NSFileProtectionCompleteUnlessOpen, NSFileProtectionCompleteUntilFirstUserAuthentication, nil];
            if ([validFileProtections containsObject:fileProtection]) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.pathsToFileProtection];
                dict[path] = fileProtection;
                self.pathsToFileProtection = dict;
            }
        }
    });
}

@end

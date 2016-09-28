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

#import "CSFNetwork+Internal.h"
#import "CSFInternalDefines.h"

@implementation CSFNetwork (Caching)

- (NSPointerArray*)outputCachePointers {
    if (!_outputCachePointers) {
        _outputCachePointers = [NSPointerArray weakObjectsPointerArray];
    }
    return _outputCachePointers;
}

- (void)configureOfflineCache {
    @synchronized (_outputCachePointers) {
        if (![self hasCacheBeenConfigured]) {
            self.cacheIsConfigured = YES;
            for (Class cacheClass in CSFClassesConformingToProtocol(@protocol(CSFNetworkOutputCache))) {
                if (class_getClassMethod(cacheClass, @selector(cacheInstanceForNetwork:))) {
                    NSObject<CSFNetworkOutputCache> *instance = [cacheClass cacheInstanceForNetwork:self];
                    if (instance) {
                        [self addOutputCache:instance];
                    }
                }
            }
        }
    }
}

- (BOOL)isOfflineCacheEnabled {
    [self configureOfflineCache];

    BOOL result = (_outputCachePointers.count > 0) ? YES : NO;
    if (_offlineCacheEnabled) {
        result = [_offlineCacheEnabled boolValue];
    }

    return result;
}

- (void)setOfflineCacheEnabled:(BOOL)offlineCacheEnabled {
    _offlineCacheEnabled = @(offlineCacheEnabled);
}

- (NSArray*)outputCaches {
    return [self.outputCachePointers allObjects];
}

- (void)addOutputCache:(NSObject<CSFNetworkOutputCache> *)outputCache {
    if ([outputCache conformsToProtocol:@protocol(CSFNetworkOutputCache)]) {
        [self.outputCachePointers addPointer:(__bridge void *)(outputCache)];
    }
}

- (void)removeOutputCache:(NSObject<CSFNetworkOutputCache> *)outputCache {
    if ([outputCache conformsToProtocol:@protocol(CSFNetworkOutputCache)]) {
        NSUInteger index = NSNotFound;
        for (NSUInteger idx = 0; idx < self.outputCachePointers.count; idx++) {
            NSObject<CSFNetworkOutputCache> *outputPointer = [self.outputCachePointers pointerAtIndex:idx];
            if (outputPointer == outputCache) {
                index = idx;
                break;
            }
        }

        if (index != NSNotFound) {
            [self.outputCachePointers removePointerAtIndex:index];
        }
    }
}

@end

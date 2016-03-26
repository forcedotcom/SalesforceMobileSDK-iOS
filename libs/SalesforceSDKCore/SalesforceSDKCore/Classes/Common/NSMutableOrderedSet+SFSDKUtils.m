/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKWeakObjectContainer.h"

@implementation NSMutableOrderedSet (SFSDKWeakObjects)

- (void)msdkAddObjectToWeakify:(id)obj {
    if (obj != nil && ![self msdkContainsWeakifiedObject:obj]) {
        
        SFSDKWeakObjectContainer *weakDelegateContainer = [[SFSDKWeakObjectContainer alloc] initWithObject:obj];
        [self addObject:weakDelegateContainer];
    }
}

- (void)msdkRemoveWeakifiedObject:(id)obj {
    if (obj != nil) {
        NSUInteger objectIndex = [self msdkIndexOfWeakifiedObject:obj];
        if (objectIndex != NSNotFound) {
            [self removeObjectAtIndex:objectIndex];
        }
    }
}

- (void)msdkEnumerateWeakifiedObjectsWithBlock:(void (^)(id))block {
    if (block != NULL) {
        [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (![obj isKindOfClass:[SFSDKWeakObjectContainer class]]) {
                [self log:SFLogLevelWarning format:@"%@ obj expected to be '%@', actually '%@'.  No action taken.", NSStringFromSelector(_cmd), NSStringFromClass([SFSDKWeakObjectContainer class]), NSStringFromClass([obj class])];
            } else {
                id internalObj = ((SFSDKWeakObjectContainer *)obj).object;
                if (internalObj != nil) {
                    block(internalObj);
                }
            }
        }];
    }
}


- (BOOL)msdkContainsWeakifiedObject:(id)obj {
    NSUInteger objIndex = [self msdkIndexOfWeakifiedObject:obj];
    return (objIndex != NSNotFound);
}

- (NSUInteger)msdkIndexOfWeakifiedObject:(id)obj {
    if (obj == nil) return NSNotFound;
    NSUInteger objIndex = [self indexOfObjectPassingTest:^BOOL(id  _Nonnull setObj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![setObj isKindOfClass:[SFSDKWeakObjectContainer class]]) {
            return NO;
        } else {
            return (((SFSDKWeakObjectContainer*)setObj).object == obj);
        }
    }];
    return objIndex;
}

@end

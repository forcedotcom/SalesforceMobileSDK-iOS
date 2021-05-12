/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKLogoutBlocker.h"
#import <objc/runtime.h>
#import "SFSDKCoreLogger.h"
#import "SFUserAccountManager+Instrumentation.h"
#import "SFOAuthCredentials.h"

@interface SFSDKLogoutBlocker()
- (void)dummy_logout;
- (void)dummy_logoutUser:(SFUserAccount *)user;
- (void)dummy_logoutAllUsers;
- (void)dummy_revokeAccessToken;
- (void)dummy_revokeRefreshToken;
- (void)dummy_revoke;
@end

@implementation SFSDKLogoutBlocker


+ (instancetype)block {
    static dispatch_once_t pred;
    static SFSDKLogoutBlocker *swizzled = nil;
    dispatch_once(&pred, ^{
        swizzled = [[self alloc] init];
    });
    return swizzled;
}

+ (void)load {
       static dispatch_once_t onceSwizzled;
        dispatch_once(&onceSwizzled, ^{
            [SFSDKCoreLogger d:[self class] format:@"Swizzled logout methods for Logout protection."];
            SEL originalSelector = @selector(logout);
            SEL swizzledSelector = @selector(dummy_logout);
            [self swizzleMethod:originalSelector with:swizzledSelector forClass:[SFUserAccountManager class]  isInstanceMethod:YES];
            originalSelector = @selector(logoutAllUsers);
            swizzledSelector = @selector(dummy_logoutAllUsers);
            [self swizzleMethod:originalSelector with:swizzledSelector forClass:[SFUserAccountManager class]  isInstanceMethod:YES];
            originalSelector = @selector(logoutUser:);
            swizzledSelector = @selector(dummy_logoutUser:);
            [self swizzleMethod:originalSelector with:swizzledSelector forClass:[SFUserAccountManager class]   isInstanceMethod:YES];
        });
}

- (void)dummy_logout {
}

- (void)dummy_logoutUser:(SFUserAccount *)user {
}

- (void)dummy_logoutAllUsers {
}

- (void)dummy_revoke {
}

- (void)dummy_revokeAccessToken {
}

- (void)dummy_revokeRefreshToken{
}

+ (void)swizzleMethod:(SEL)originalSelector with:(SEL)swizzledSelector forClass:(Class)clazz isInstanceMethod:(BOOL)isInstanceMethod {
    Method originalMethod;
    Method swizzledMethod;
    if (isInstanceMethod) {
        originalMethod = class_getInstanceMethod(clazz, originalSelector);
        swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
    } else {
        originalMethod = class_getClassMethod(clazz, originalSelector);
        swizzledMethod = class_getClassMethod(self, swizzledSelector);
    }
    BOOL didAddMethod =
    class_addMethod(clazz,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(clazz,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}
@end

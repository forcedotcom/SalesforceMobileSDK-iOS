/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#include "UIApplication+SalesforceHybridSDK.h"
#include <objc/runtime.h>

@interface UIApplication (SalesforceHybridSDKPrivate)

@property (atomic, readwrite, strong) NSDate *lastEventDate;

- (void)keyPressed:(NSNotification *)notification;

@end

@implementation UIApplication (SalesforceHybridSDK)

+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(init)), class_getInstanceMethod(self, @selector(sfsdk_swizzled_init)));
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(sendEvent:)), class_getInstanceMethod(self, @selector(sfsdk_swizzled_sendEvent:)));
}

- (id)sfsdk_swizzled_init
{
    self.lastEventDate = [NSDate date];
    NSNotificationCenter *ctr = [NSNotificationCenter defaultCenter];
    [ctr addObserver:self selector:@selector(keyPressed:) name:UITextFieldTextDidChangeNotification object:nil];
    [ctr addObserver:self selector:@selector(keyPressed:) name:UITextViewTextDidChangeNotification object:nil];
    
    return [self sfsdk_swizzled_init];
}

- (void)sfsdk_swizzled_sendEvent:(UIEvent *)event
{
    NSSet *allTouches = [event allTouches];
    if ([allTouches count] > 0) {
        UITouchPhase phase = ((UITouch *)[allTouches anyObject]).phase;
        if (phase == UITouchPhaseEnded) {
            self.lastEventDate = [NSDate date];
        }
    }
    
    [self sfsdk_swizzled_sendEvent:event];
}

static NSDate *__lastEventDate = nil;
- (void)setLastEventDate:(NSDate *)lastEventDate
{
    @synchronized (self) {
        if (lastEventDate != __lastEventDate) {
            __lastEventDate = lastEventDate;
        }
    }
}

- (NSDate *)lastEventDate
{
    @synchronized (self) {
        return __lastEventDate;
    }
}

- (void)keyPressed:(NSNotification *)notification
{
    self.lastEventDate = [NSDate date];
}

@end

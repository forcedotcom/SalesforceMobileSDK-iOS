/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFApplication.h"

@interface SFApplication ()

@property (atomic, readwrite, strong) NSDate *lastEventDate;

/**
 * Boolean which defaults to NO, and is only set to YES in the viewDidAppear and is set to NO in the dealloc of the VC.
 * The boolean is used to ignore the keypressed & touch gestures in the UIApplication's sendEvents & keyPressed methods.  Otherwise, the lastEventDate
 * variable was being updated and if the timing was right on the Notification/Control Center displaying the PIN Code View could be circumvented.
 */
@property (nonatomic) BOOL ignoreEvents;

- (void)keyPressed:(NSNotification *)notification;

@end

@implementation SFApplication

@synthesize lastEventDate = _lastEventDate;

#pragma mark - init / dealloc / etc.

- (id)init
{
    self = [super init];
    if (self) {
        self.lastEventDate = [NSDate date];
        NSNotificationCenter *ctr = [NSNotificationCenter defaultCenter];
        [ctr addObserver:self selector:@selector(keyPressed:) name:UITextFieldTextDidChangeNotification object:nil];
        [ctr addObserver:self selector:@selector(keyPressed:) name:UITextViewTextDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    NSNotificationCenter *ctr = [NSNotificationCenter defaultCenter];
    [ctr removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
    [ctr removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
}

#pragma mark - Event handling

- (void)sendEvent:(UIEvent *)event
{
    NSSet *allTouches = [event allTouches];
    if ([allTouches count] > 0) {
        UITouchPhase phase = ((UITouch *)[allTouches anyObject]).phase;
        if (phase == UITouchPhaseEnded) {
            if (!self.ignoreEvents) {
                self.lastEventDate = [NSDate date];
            }
        }
    }
    
    [super sendEvent:event];
}

- (void)keyPressed:(NSNotification *)notification
{
    if (!self.ignoreEvents) {
        self.lastEventDate = [NSDate date];
    }
}

@end

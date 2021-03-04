/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFTestSDKManagerFlow.h"

@interface SFTestSDKManagerFlow ()

@property (nonatomic,copy,nullable) void (^switchUserCompletionBlock)(SFUserAccount *,SFUserAccount *,BOOL before);
@end

@implementation SFTestSDKManagerFlow

#pragma mark - Public methods

- (void)setUpUserSwitchState:(SFUserAccount *) fromUser toUser:(SFUserAccount *) toUser completion:(void (^)(SFUserAccount *,SFUserAccount *,BOOL before))switchUserCompletionBlock {
    self.switchUserCompletionBlock = switchUserCompletionBlock;
}

- (void)clearUserSwitchState {
    self.switchUserCompletionBlock = nil;
}

#pragma mark - SalesforceSDKManagerFlow

- (void)handleAppForeground:(NSNotification *)notification
{
    
}

- (void)handleAppBackground:(NSNotification *)notification
{
    
}

- (void)handlePostLogout
{
    
}

- (void)handleAppTerminate:(NSNotification *)notification
{
    
}

- (void)handleAuthCompleted:(NSNotification *)notification
{
    
}

- (void)handleUserWillSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    if (self.switchUserCompletionBlock) {
        self.switchUserCompletionBlock(fromUser, toUser,YES);
    }
}

- (void)handleUserDidSwitch:(SFUserAccount *)fromUser toUser:(SFUserAccount *)toUser
{
    if (self.switchUserCompletionBlock) {
        self.switchUserCompletionBlock(fromUser, toUser,NO);
    }
}

- (void)handleIDPInitiatedAuthCompleted:(nonnull NSNotification *)notification {

}

- (void)handleUserDidLogout:(nonnull NSNotification *)notification {

}

@end

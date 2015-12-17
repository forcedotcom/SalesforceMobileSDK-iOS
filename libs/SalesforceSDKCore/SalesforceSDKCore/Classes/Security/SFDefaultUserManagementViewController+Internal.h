/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFDefaultUserManagementViewController.h"

@interface SFDefaultUserManagementViewController ()

/**
 The action to take, once the user interface has been cleared by the consumer.
 */
@property (nonatomic, assign) SFUserManagementAction action;

/**
 The optional account associated with the action to take.
 */
@property (nonatomic, strong) SFUserAccount *actionAccount;

/**
 Completion block to execute, once a user management action has been selected.
 */
@property (nonatomic, copy) SFUserManagementCompletionBlock completionBlock;

/**
 Logs out the current user, once the user interface is cleared.
 */
- (void)actionLogout;

/**
 Switches to the given user, once the user interface is cleared.
 @param user The user to switch to.
 */
- (void)actionSwitchUser:(SFUserAccount *)user;

/**
 Creates a new user and switches to that user, once the user interface is cleared.
 */
- (void)actionCreateNewUser;

/**
 Executes the completion block.
 @param action The user management action to pass to the completion block.
 @param actionAccount The optional account on which the action will be taken.
 */
- (void)execCompletionBlock:(SFUserManagementAction)action account:(SFUserAccount *)actionAccount;

@end

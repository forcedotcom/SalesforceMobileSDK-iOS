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

#import <UIKit/UIKit.h>
#import "SFUserAccount.h"

/** The various actions that may have been taken for account management.
 */
typedef NS_ENUM(NSUInteger, SFUserManagementAction) {
    /** No action was taken.
     */
    SFUserManagementActionCancel = 0,
    
    /** A user was logged out.
     */
    SFUserManagementActionLogoutUser,
    
    /** Switched from one user to another.
     */
    SFUserManagementActionSwitchUser,
    
    /** Logging in as a new user.
     */
    SFUserManagementActionCreateNewUser
};

/**
 Type definition for the user management completion block.
 */
typedef void (^SFUserManagementCompletionBlock)(SFUserManagementAction action);

/**
 View controller for managing the different users of the app.
 */
@interface SFDefaultUserManagementViewController : UINavigationController

/**
 Creates an instance with the given completion block.
 @param completionBlock The (optional) completion block to execute once action has been taken.
 */
- (id)initWithCompletionBlock:(SFUserManagementCompletionBlock)completionBlock;

@end

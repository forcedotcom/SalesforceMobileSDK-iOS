/*
 SFSDKAuthHelper.h
 SalesforceSDKCore
 
 Created by Raj Rao on 07/19/18.
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AuthHelper)
@interface SFSDKAuthHelper : NSObject

/**
 Initiate a login flow if the user is not already logged in to Salesforce and if the app config's `shouldAuthenticate` flag is set to false.
 
 @param completionBlock Block that executes immediately if the user is already logged in, or if the app config's `shouldAuthenticate` is set to false.
                        Otherwise, this block executes after the user logs in successfully, if login is required.
 */
+ (void)loginIfRequired:(nullable void (^)(void))completionBlock;

/**
 Initiate a login flow if the user is not already logged in to Salesforce and if the app config's `shouldAuthenticate` flag is set to false.
 
 @param scene Scene that login is initiated for.
 @param completionBlock Block that executes immediately if the user is already logged in, or if the app config's `shouldAuthenticate` is set to false.
                        Otherwise, this block executes after the user logs in successfully, if login is required.
 */
+ (void)loginIfRequired:(UIScene *)scene completion:(nullable void (^)(void))completionBlock;

+ (void)handleLogout:(nullable void (^)(void))completionBlock;

+ (void)handleLogout:(UIScene *)scene completion:(nullable void (^)(void))completionBlock;

+ (void)registerBlockForCurrentUserChangeNotifications:(void (^)(void))completionBlock;

+ (void)registerBlockForCurrentUserChangeNotifications:(UIScene *)scene completion:(void (^)(void))completionBlock;

+ (void)registerBlockForLogoutNotifications:(void (^)(void))completionBlock;

+ (void)registerBlockForLogoutNotifications:(UIScene *)scene completion:(void (^)(void))completionBlock;

+ (void)registerBlockForSwitchUserNotifications:(void (^)(void))completionBlock;

@end

NS_ASSUME_NONNULL_END

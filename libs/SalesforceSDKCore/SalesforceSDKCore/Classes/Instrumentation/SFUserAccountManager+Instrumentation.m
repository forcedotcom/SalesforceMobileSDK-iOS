/*
 SFUserAccountManager+Instrumentation.m
 SalesforceSDKCore
 Created by Raj Rao on 3/7/19.
 
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

#import "SFUserAccountManager+Instrumentation.h"
#import "SFSDKInstrumentationHelper.h"
#import <objc/runtime.h>
#import <os/log.h>
#import <os/signpost.h>
#import "SFSDKCoreLogger.h"

@implementation SFUserAccountManager(Instrumentation)

+ (os_log_t)oslog {
    static os_log_t _logger;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
         NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        _logger = os_log_create([appName  cStringUsingEncoding:NSUTF8StringEncoding], [@"SFUserAccountManager" cStringUsingEncoding:NSUTF8StringEncoding]);
    });
    return _logger;
}


+ (void)load{
    
    if ([SFSDKInstrumentationHelper isEnabled] && (self == SFUserAccountManager.self)) {
       [self enableInstrumentation];
    }
}


+ (void)enableInstrumentation{
    static dispatch_once_t once;
     dispatch_once(&once, ^{
        [SFSDKCoreLogger d:[self class] format:@"Swizzled :: SFUserAccountManager"];
        
        SEL originalSelector = @selector(loginWithCompletion:failure:);
        SEL swizzledSelector = @selector(instr_loginWithCompletion:failure:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:self  isInstanceMethod:YES];
        
        originalSelector = @selector(refreshCredentials:completion:failure:);
        swizzledSelector = @selector(instr_refreshCredentials:completion:failure:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:self  isInstanceMethod:YES];
        
        originalSelector = @selector(loginWithJwtToken:completion:failure:);
        swizzledSelector = @selector(instr_loginWithJwtToken:completion:failure:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:self  isInstanceMethod:YES];
        
        originalSelector = @selector(logout);
        swizzledSelector = @selector(instr_logout);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:self  isInstanceMethod:YES];
        
        originalSelector = @selector(logoutAllUsers);
        swizzledSelector = @selector(instr_logoutAllUsers);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:self  isInstanceMethod:YES];
        
        originalSelector = @selector(logoutUser:);
        swizzledSelector = @selector(instr_logoutUser:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:self  isInstanceMethod:YES];
     });
}

- (BOOL)instr_loginWithCompletion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                    failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock {
    // Begin an os_signpost_interval.
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "Salesforce Login", "Begin");
    
    return [self instr_loginWithCompletion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        sf_os_signpost_interval_end(logger, sid, "Salesforce Login", "End - Success");
        if (completionBlock) completionBlock(authInfo,account);
    } failure:^(SFOAuthInfo * authInfo, NSError * error) {
        sf_os_signpost_interval_end(logger, sid, "Salesforce Login", "End - Failure");
        if (failureBlock) failureBlock(authInfo,error);
    }];
   
}


- (BOOL)instr_refreshCredentials:(nonnull SFOAuthCredentials *)credentials
                completion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                         failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock {
    // Begin an os_signpost_interval.
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "Salesforce Refresh", "Begin");
    
    return [self instr_refreshCredentials:credentials completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        sf_os_signpost_interval_end(logger, sid, "Salesforce Refresh", "End - Success");
        if (completionBlock) completionBlock(authInfo,account);
    } failure:^(SFOAuthInfo * authInfo, NSError * error) {
        sf_os_signpost_interval_end(logger, sid, "Salesforce Refresh", "End - Failure");
        if (failureBlock) failureBlock(authInfo,error);
    }];
}

- (BOOL)instr_loginWithJwtToken:(NSString *)jwtToken
               completion:(nullable SFUserAccountManagerSuccessCallbackBlock)completionBlock
                        failure:(nullable SFUserAccountManagerFailureCallbackBlock)failureBlock {
    // Begin an os_signpost_interval.
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "Salesforce Login JWT", "Begin");
    
    return [self instr_loginWithJwtToken:jwtToken completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        sf_os_signpost_interval_end(logger, sid, "Salesforce Login JWT", "Did Login user %{public}@",account.idData.username);
        if (completionBlock) completionBlock(authInfo,account);
    } failure:^(SFOAuthInfo * authInfo, NSError * error) {
        sf_os_signpost_interval_end(logger, sid, "Salesforce Login JWT", "Login - Failure");
        if (failureBlock) failureBlock(authInfo,error);
    }];
}

- (void)instr_logout {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    NSString *currentUsername = self.currentUser.idData.username;
    sf_os_signpost_interval_begin(logger, sid, "Salesforce Logout", "Will Logout current user %{public}@",currentUsername);
    [self instr_logout];
    sf_os_signpost_interval_end(logger, sid, "Salesforce Logout", "Did Logout current user %{public}@",currentUsername);
       return;
}

- (void)instr_logoutUser:(SFUserAccount *)user {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    NSString *username = user.idData.username;
    sf_os_signpost_interval_begin(logger, sid, "Salesforce Logout User","Will Logout user %{public}@",username);
    [self instr_logoutUser:user];
    sf_os_signpost_interval_end(logger, sid, "Salesforce Logout User", "Did Logout user %{public}@",username);
    return;
}

- (void)instr_logoutAllUsers {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "Salesforce Logout All Users", "Begin");
    [self instr_logoutAllUsers];
    sf_os_signpost_interval_end(logger, sid, "Salesforce Logout All Users", "End - Success");
   
}

@end

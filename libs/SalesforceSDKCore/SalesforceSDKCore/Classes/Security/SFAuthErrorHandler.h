/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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

@class SFOAuthInfo;

/**
 Block definition for auth error handling evaluation block.
 */
typedef BOOL (^SFAuthErrorHandlerEvalBlock)(NSError *, SFOAuthInfo *);

/**
 Class to define a handler for authentication errors, which can be used in an
 error handling filter chain.
 @see SFAuthenticationManager
 */
@interface SFAuthErrorHandler : NSObject

/**
 The canonical name of the error handler.
 */
@property (nonatomic, readonly) NSString *name;

/**
 The block of code that will evaluate the error.  The block should return YES if it can
 handle the error, and NO if the error should be passed on to the next handler.
 */
@property (nonatomic, readonly) SFAuthErrorHandlerEvalBlock evalBlock;

/**
 Designated initializer for SFAuthErrorHandler.
 @param name The canonical name of the error handler.
 @param evalBlock The block to handle the error evaluation.
 */
- (id)initWithName:(NSString *)name evalBlock:(SFAuthErrorHandlerEvalBlock)evalBlock;

@end

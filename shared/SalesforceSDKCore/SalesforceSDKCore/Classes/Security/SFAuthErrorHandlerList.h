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

@class SFAuthErrorHandler;

/**
 Manages the authentication handler filter list, for processing authentication errors.  Note that
 order of entries is important: the list will be processed serially, starting with the first item
 and ending with the last.
 */
@interface SFAuthErrorHandlerList : NSObject

/**
 A readonly copy of the array of authentication error handlers.
 */
@property (nonatomic, readonly) NSArray *authHandlerArray;

/**
 Adds an authentication error handler to the end of the filter list.  Note: Error handler
 names must be unique within the list, so if an error handler already exists with the
 given name, it will be removed before adding the new handler.
 @param errorHandler The error handler to add to the list.
 */
- (void)addAuthErrorHandler:(SFAuthErrorHandler *)errorHandler;

/**
 Adds an authentication error handler at a specific index in the list.  Note: Error handler
 names must be unique within the list, so if an error handler already exists with the
 given name, it will be removed before adding the new handler.
 @param errorHandler The error handler to add to the list.
 @param index The index at which to add the error handler.
 */
- (void)addAuthErrorHandler:(SFAuthErrorHandler *)errorHandler atIndex:(NSUInteger)index;

/**
 Removes the error handler with the given name from the list.  If no error handler exists
 in the list with the name, no action is taken.
 @param errorHandlerName The name of the error handler to remove.
 */
- (void)removeAuthErrorHandlerWithName:(NSString *)errorHandlerName;

/**
 Removes the given error handler from the list.  If the error handler cannot be found, no
 action is taken.
 @param errorHandler The error handler to remove.
 */
- (void)removeAuthErrorHandler:(SFAuthErrorHandler *)errorHandler;

/**
 Determines whether the given error handler is in the list.
 @param errorHandler The error handler to look for in the list.
 @return YES if the error handler is in the list, NO otherwise.
 */
- (BOOL)authErrorHandlerInList:(SFAuthErrorHandler *)errorHandler;

@end

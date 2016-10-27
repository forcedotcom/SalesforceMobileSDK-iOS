/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "CSFAction.h"

NS_ASSUME_NONNULL_BEGIN

CSF_EXTERN NSString * const CSFSalesforceActionDefaultPathPrefix;
CSF_EXTERN NSString * const CSFSalesforceDefaultAPIVersion;

@interface CSFSalesforceAction : CSFAction

/**
 Indicates if the action requires a security token. In this case, this action
 must be executed only after all the previous actions are completed to ensure
 it gets the latest security token.
 */
@property (nonatomic, readonly) BOOL requiresSecurityToken;

/**
 Indicates if the action returns a new security token as part of its response.
 A security token is returned for all GET requests, except the ones that
 will return a binary data, such as for images and thumbnails.
 */
@property (nonatomic, readonly) BOOL returnsSecurityToken;

@property (nullable, nonatomic, copy) NSString *pathPrefix;
@property (nullable, nonatomic, copy) NSString *apiVersion;

/**
 * Returns YES if error is a network error
 */
+ (BOOL)isNetworkError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

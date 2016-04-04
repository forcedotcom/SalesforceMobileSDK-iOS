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

#import "CSFActionModel.h"
#import "CSFInternalDefines.h"
#import "CSFAuthRefresh.h"
#import "CSFParameterStorage.h"

@class SFUserAccount;

CSF_EXTERN NSString * const CSFActionSecurityTokenKey;

CSF_EXTERN NSString * const CSFDefaultLocale;

CSF_EXTERN NSTimeInterval const CSFActionDefaultTimeOut;

/** Internal interface to be used only by subclasses of CHAction and CHActionExecuter.
 */
@interface CSFAction () {
    NSProgress *_progress;
    
    @protected
    NSString *_verb;
    NSNumber *_shouldCacheResponse;
    __weak CSFNetwork *_enqueuedNetwork;
}

@property (nonatomic, weak, readwrite) CSFNetwork *enqueuedNetwork;

/** URL path prefix used as the basis for action requests.
 */
@property (nonatomic, copy, readonly) NSString *basePath;

@property (nonatomic, readwrite) NSUInteger retryCount;

@property (nonatomic, strong, readwrite) NSObject<CSFActionModel> *outputModel;

@property (nonatomic, strong, readwrite) id outputContent;
@property (nonatomic, strong) CSFAction *duplicateParentAction;
@property (nonatomic, strong) NSURLSessionTask *sessionTask;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic, strong) CSFAuthRefresh *authRefreshInstance;
@property (nonatomic, strong, readwrite) NSURL *downloadLocation;
@property (nonatomic) BOOL credentialsReady;

+ (NSError *)errorInResponseDataForAction:(CSFAction*)action;

- (NSURL*)urlForActionWithError:(NSError**)error;

- (void)completeOperationWithResponse:(NSHTTPURLResponse*)response;

- (void)sessionDownloadTask:(NSURLSessionDownloadTask*)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;
- (void)sessionUploadTask:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;
- (void)sessionDownloadTask:(NSURLSessionDownloadTask*)task didFinishDownloadingToURL:(NSURL *)location;

@end

/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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
#import <WebKit/WebKit.h>
#import "SFSDKWebViewStateManager.h"

static NSString *const SID_COOKIE = @"sid";
static NSString *const TRUE_STRING = @"TRUE";
static NSString *const ERR_NO_DOMAIN_NAMES = @"No domain names given for deleting cookies.";
static NSString *const ERR_NO_COOKIE_NAMES = @"No cookie names given to delete.";

@implementation SFSDKWebViewStateManager

static WKProcessPool *_processPool = nil;

+ (void)resetSessionWithNewAccessToken:(NSString *)accessToken isSecureProtocol:(BOOL)isSecure {
     //reset UIWebView related state if any
    [self removeUIWebViewCookies:@[SID_COOKIE] fromDomains:self.domains];
    [self addSidCookieForDomain:SID_COOKIE withAccessToken:accessToken isSecureProtocol:isSecure];
    [self removeWKWebViewCookies:self.domains withCompletion:nil];
}

+ (void)removeSession {
    //reset UIWebView related state if any
    [self removeUIWebViewCookies:@[SID_COOKIE] fromDomains:self.domains];
    self.sharedProcessPool = nil;
}

+ (WKProcessPool *)sharedProcessPool {
    if (!_processPool) {
        _processPool = [[WKProcessPool alloc] init];
    }
    return _processPool;
}

+ (void)setSharedProcessPool:(WKProcessPool *)sharedProcessPool {
    if (sharedProcessPool != _processPool) {
        _processPool = sharedProcessPool;
    }
}

#pragma mark Private helper methods
+ (void)removeUIWebViewCookies:(NSArray *)cookieNames fromDomains:(NSArray *)domainNames
{
    NSAssert(cookieNames != nil && [cookieNames count] > 0, ERR_NO_COOKIE_NAMES);
    NSAssert(domainNames != nil && [domainNames count] > 0, ERR_NO_DOMAIN_NAMES);
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        for (NSString *cookieToRemoveName in cookieNames) {
            if ([[cookie.name lowercaseString] isEqualToString:[cookieToRemoveName lowercaseString]]) {
                for (NSString *domainToRemoveName in domainNames) {
                    if ([[cookie.domain lowercaseString] hasSuffix:[domainToRemoveName lowercaseString]]) {
                        [cookieStorage deleteCookie:cookie];
                    }
                }
            }
        }
    }
}

+ (void)removeWKWebViewCookies:(NSArray *)domainNames withCompletion:(nullable void(^)())completionBlock
{
    NSAssert(domainNames != nil && [domainNames count] > 0, ERR_NO_DOMAIN_NAMES);
    WKWebsiteDataStore *dateStore = [WKWebsiteDataStore defaultDataStore];
    NSSet *websiteDataTypes = [NSSet setWithArray:@[ WKWebsiteDataTypeCookies]];
    [dateStore fetchDataRecordsOfTypes:websiteDataTypes
                     completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {

                         NSMutableArray<WKWebsiteDataRecord *> *deletedRecords = [NSMutableArray new];
                         for ( WKWebsiteDataRecord * record in records) {
                             for(NSString *domainName in domainNames) {
                                 if ([record.displayName containsString:domainName]) {
                                     [deletedRecords addObject:record];
                                 }
                             }
                         }
                         if (deletedRecords.count > 0)
                             [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                                                       forDataRecords:deletedRecords
                                                                    completionHandler:^{
                                                                        if (completionBlock)
                                                                            completionBlock();
                                                                    }];
                     }];
}
+ (void)addSidCookieForDomain:(NSString*)domain withAccessToken:accessToken isSecureProtocol:(BOOL)isSecure
{
    NSAssert(domain != nil && [domain length] > 0, @"addSidCookieForDomain: domain cannot be empty");
    [SFSDKCoreLogger d:[self class] format:@"addSidCookieForDomain: %@", domain];

    // Set the session ID cookie to be used by the web view.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    NSMutableDictionary *newSidCookieProperties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            domain, NSHTTPCookieDomain,
            @"/", NSHTTPCookiePath,
            accessToken, NSHTTPCookieValue,
            SID_COOKIE, NSHTTPCookieName,
            TRUE_STRING, NSHTTPCookieDiscard,
                    nil];
    if (isSecure) {
        newSidCookieProperties[NSHTTPCookieSecure] = TRUE_STRING;
    }

    NSHTTPCookie *sidCookie0 = [NSHTTPCookie cookieWithProperties:newSidCookieProperties];
    [cookieStorage setCookie:sidCookie0];
}

+ (NSArray<NSString *> *) domains {
    return @[@".salesforce.com", @".force.com", @".cloudforce.com"];
}
@end

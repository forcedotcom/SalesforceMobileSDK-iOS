/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh@salesforce.com
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFRestAPI+PMRequests.h"

@implementation SFRestAPI (PMRequests)

static NSString * const kMyConversationsPath =                      @"/chatter/users/me/conversations";
static NSString * const kConversationUnreadCountPath =              @"/chatter/users/me/conversations/unread-count";
static NSString * const kPathForConversationStatusChange =          @"/chatter/users/me/conversations/%@/mark-read";
static NSString * const kPathForConversationWithConversationId =    @"/chatter/users/me/conversations/%@";
static NSString * const kPathForUserMessages =                      @"/chatter/users/me/messages";

+ (NSString *)truncateBodyString:(NSString *)body {
    if( !body || [body length] < kMaxCharactersPerMessage )
        return body;
    
    return [body substringToIndex:kMaxCharactersPerMessage];
}

#pragma mark - creating SFRestRequests

+ (NSString *) serviceEndPointForPath:(NSString *)path {
    return [[[SFRestAPI sharedInstance] apiVersion] stringByAppendingString:path];
}

+ (SFRestRequest *)requestForConversationsWithSearchTerm:(NSString *)searchTerm pageToken:(NSString *)pageToken {
    NSMutableDictionary *requestDict = [NSMutableDictionary dictionary];
    
    if( searchTerm && [searchTerm length] > 0 )
        [requestDict setObject:searchTerm
                        forKey:@"q"];
    
    if( pageToken && [pageToken length] > 0 )
        [requestDict setObject:pageToken
                        forKey:@"page"];   
    
    return [SFRestRequest requestWithMethod:SFRestMethodGET
                                       path:[self serviceEndPointForPath:kMyConversationsPath]
                                queryParams:requestDict];
}

+ (SFRestRequest *)requestForConversationWithId:(NSString *)conversationId searchTerm:(NSString *)searchTerm {
    return [SFRestRequest requestWithMethod:SFRestMethodGET
                                       path:[self serviceEndPointForPath:[NSString stringWithFormat:kPathForConversationWithConversationId, conversationId]]
                                queryParams:( searchTerm && [searchTerm length] > 0
                                              ? [NSDictionary dictionaryWithObject:searchTerm forKey:@"q"]
                                              : nil )];
}

+ (SFRestRequest *)requestForConversationUnreadCount {
    return [SFRestRequest requestWithMethod:SFRestMethodGET
                                       path:[self serviceEndPointForPath:kConversationUnreadCountPath]
                                queryParams:nil];
}

+ (SFRestRequest *)requestToChangeStatusWithConversationId:(NSString *)conversationId markAsRead:(BOOL)markAsRead {
    return [SFRestRequest requestWithMethod:SFRestMethodPOST
                                       path:[self serviceEndPointForPath:[NSString stringWithFormat:kPathForConversationStatusChange, conversationId]]
                                queryParams:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:markAsRead]
                                                                        forKey:@"read"]];
}

+ (SFRestRequest *)requestToPostNewMessageThreadWithRecipients:(NSArray *)recipients body:(NSString *)body {
    return [SFRestRequest requestWithMethod:SFRestMethodPOST
                                       path:[self serviceEndPointForPath:kPathForUserMessages]
                                queryParams:[NSDictionary dictionaryWithObjectsAndKeys:
                                             recipients, @"recipients",
                                             [self truncateBodyString:body], @"body",
                                             nil]];
}

+ (SFRestRequest *)requestToPostReplyToMessageWithId:(NSString *)messageId body:(NSString *)body {
    return [SFRestRequest requestWithMethod:SFRestMethodPOST
                                       path:[self serviceEndPointForPath:kPathForUserMessages]
                                queryParams:[NSDictionary dictionaryWithObjectsAndKeys:
                                             messageId, @"inReplyTo",
                                             [self truncateBodyString:body], @"body",
                                             nil]];
}

@end

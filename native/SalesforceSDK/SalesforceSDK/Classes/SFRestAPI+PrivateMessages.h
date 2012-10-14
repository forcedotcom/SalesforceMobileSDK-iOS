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

#import <Foundation/Foundation.h>
#import "SFRestAPI.h"

static NSInteger const kMaxCharactersPerMessage = 10000;

@interface SFRestAPI (PrivateMessages)

/**
 * Truncates a string to the maximum private message body length
 * (currently 10000 characters, or kMaxCharactersPerMessage)
 * @param body - body text
 * @return truncated body
 */
+ (NSString *) truncateBodyString:(NSString *)body;

/* Creating REST requests */

/**
 * Returns an SFRestRequest for loading all conversations (the user's inbox).
 * @param searchTerm - optional. if specified, returns conversations matching this term
 * @param pageToken - optional. if specified, returns a second (or third, etc) page of the inbox.
 * responses from this request will include a pagetoken.
 * @return a prepared SFRestRequest
 */
+ (SFRestRequest *) requestForConversationsWithSearchTerm:(NSString *)searchTerm 
                                                pageToken:(NSString *)pageToken;

/**
 * Returns an SFRestRequest for an individual private message conversation thread.
 * @param conversationId - required. the conversation Id
 * @param searchTerm - optional. if specified, returns only the messages in this conversation matching search term.
 * @return a prepared SFRestRequest
 */
+ (SFRestRequest *) requestForConversationWithId:(NSString *)conversationId 
                                      searchTerm:(NSString *)searchTerm;

/**
 * Returns an SFRestRequest for requesting the number of unread conversations.
 * @return a prepared SFRestRequest
 */
+ (SFRestRequest *) requestForConversationUnreadCount;


/**
 * Returns an SFRestRequest for changing the read/unread status of a particular conversation thread.
 * @param conversationId - required. the conversation Id to change
 * @param markAsRead - required. the unread status to set
 * @return a prepared SFRestRequest
 */
+ (SFRestRequest *) requestToChangeStatusWithConversationId:(NSString *)conversationId
                                                 markAsRead:(BOOL)markAsRead;

/**
 * Returns an SFRestRequest for creating a new private message conversation thread.
 * Recipients are checked serverside and this message will, if necessary, be merged into an
 * existing thread containing this same set of recipients.
 * @param recipients - required. the array of user IDs to include in this message.
 * @param body - required. the body text of the message to send. will be truncated to max message length.
 * @return a prepared SFRestRequest
 */
+ (SFRestRequest *) requestToPostNewMessageThreadWithRecipients:(NSArray *)recipients
                                                           body:(NSString *)body;

/**
 * Returns an SFRestRequest for sending a reply to an existing private message conversation thread.
 * @param messageId - required. This is the ID of (any?) individual message in the conversation thread,
 * ** NOT ** the ID of the conversation thread itself
 * @param body - required. the body text of the message to send. will be truncated to max message length
 * @return a prepared SFRestRequest
 */
+ (SFRestRequest *) requestToPostReplyToMessageWithId:(NSString *)messageId 
                                                 body:(NSString *)body;

@end

/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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

#ifndef __SF_USER_ACCOUNT_CONSTANTS_H__
#define __SF_USER_ACCOUNT_CONSTANTS_H__

/** User account restrictions
 */
typedef NS_OPTIONS(NSUInteger, SFUserAccountAccessRestriction) {
    SFUserAccountAccessRestrictionNone    = 0,
    SFUserAccountAccessRestrictionChatter = 1 << 0,
    SFUserAccountAccessRestrictionREST    = 1 << 1,
    SFUserAccountAccessRestrictionOther   = 1 << 2,
};

/** The various scopes related to a user account
 */
typedef NS_ENUM(NSUInteger, SFUserAccountScope) {
    /** Global scope (one per application)
     */
    SFUserAccountScopeGlobal = 0,
    
    /** Scope by organization
     */
    SFUserAccountScopeOrg,
    
    /** Scope by user
     */
    SFUserAccountScopeUser,
    
    /** Scope by community
     */
    SFUserAccountScopeCommunity
};

/** The various changes that can affect a user account
 */
typedef NS_OPTIONS(NSUInteger, SFUserAccountChange) {
    /** Unknown change
     */
    SFUserAccountChangeUnknown      = 1 << 0,
    
    /** A new user account has been created
     */
    SFUserAccountChangeNewUser      = 1 << 1,
    
    /** The credentials changed
     */
    SFUserAccountChangeCredentials  = 1 << 2,
    
    /** The organization ID changed
     */
    SFUserAccountChangeOrgId        = 1 << 3,
    
    /** The user ID changed
     */
    SFUserAccountChangeUserId       = 1 << 4,
    
    /** The community ID changed
     */
    SFUserAccountChangeCommunityId  = 1 << 5,

    /** The ID data changed
     */
    SFUserAccountChangeIdData = 1 << 6
};

#endif
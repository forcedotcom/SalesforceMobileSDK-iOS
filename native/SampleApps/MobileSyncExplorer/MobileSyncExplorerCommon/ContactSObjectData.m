/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "ContactSObjectData.h"
#import "ContactSObjectDataSpec.h"
#import "SObjectData+Internal.h"
#import <SmartSync/SFSmartSyncConstants.h>

@implementation ContactSObjectData

+ (SObjectDataSpec *)dataSpec {
    static ContactSObjectDataSpec *sDataSpec = nil;
    if (sDataSpec == nil) {
        sDataSpec = [[ContactSObjectDataSpec alloc] init];
    }
    return sDataSpec;
}

#pragma mark - Property getters / setters

- (NSString *)firstName {
    return [self nonNullFieldValue:kContactFirstNameField];
}

- (void)setFirstName:(NSString *)firstName {
    [self updateSoupForFieldName:kContactFirstNameField fieldValue:firstName];
}

- (NSString *)lastName {
    return [self nonNullFieldValue:kContactLastNameField];
}

- (void)setLastName:(NSString *)lastName {
    [self updateSoupForFieldName:kContactLastNameField fieldValue:lastName];
}

- (NSString *)title {
    return [self nonNullFieldValue:kContactTitleField];
}

- (void)setTitle:(NSString *)title {
    [self updateSoupForFieldName:kContactTitleField fieldValue:title];
}

- (NSString *)mobilePhone {
    return [self nonNullFieldValue:kContactMobilePhoneField];
}

- (void)setMobilePhone:(NSString *)mobilePhone {
    [self updateSoupForFieldName:kContactMobilePhoneField fieldValue:mobilePhone];
}

- (NSString *)email {
    return [self nonNullFieldValue:kContactEmailField];
}

- (void)setEmail:(NSString *)email {
    [self updateSoupForFieldName:kContactEmailField fieldValue:email];
}

- (NSString *)department {
    return [self nonNullFieldValue:kContactDepartmentField];
}

- (void)setDepartment:(NSString *)department {
    [self updateSoupForFieldName:kContactDepartmentField fieldValue:department];
}

- (NSString *)homePhone {
    return [self nonNullFieldValue:kContactHomePhoneField];
}

- (void)setHomePhone:(NSString *)homePhone {
    [self updateSoupForFieldName:kContactHomePhoneField fieldValue:homePhone];
}

- (NSString*)lastModifiedDate {
    return [self nonNullFieldValue:kLastModifiedDate];
}

@end

/*
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

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SFSDKPushNotificationFieldsConstants.h>
#import <SalesforceSDKCore/SFSDKPushNotificationDecryption.h>
#import <SalesforceSDKCore/SFSDKPushNotificationError.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import "SFSDKPushNotificationDataProvider.h"
#import "SFSDKPushNotificationDecryption+Internal.h"

@interface SFPushNotificationManager (Testing)

- (NSString *)getRSAPublicKey;

@end

@interface SFSDKEncryptedPushNotificationTests : XCTestCase

@property (nullable, nonatomic, strong) NSDictionary *userInfoDict;
@property (nullable, nonatomic, strong) NSDictionary *contentDict;

@end

@implementation SFSDKEncryptedPushNotificationTests

- (void)setUp {
    [super setUp];
    _contentDict = @{ kRemoteNotificationKeyAlertTitle: @"content_alert_title",
                      kRemoteNotificationKeyAlertBody: @"content_alert_body",
                      @"ContentKey1": @"ContentValue1",
                      @"ContentKey2": @"ContentValue2" };
    SFSDKPushNotificationDataProvider *pndp = [[SFSDKPushNotificationDataProvider alloc] initWithContentObj:_contentDict];
    _userInfoDict = pndp.userInfoDict;
}

- (void)testGetRSAKeySameData {
    NSString *rsaKey = [[SFPushNotificationManager sharedInstance] getRSAPublicKey];
    XCTAssertNotNil(rsaKey);
    NSString *rsaKey2 = [[SFPushNotificationManager sharedInstance] getRSAPublicKey];
    XCTAssertEqualObjects(rsaKey, rsaKey2);
}

- (void)testValidateUserInfo {
    NSDictionary *userInfo = _userInfoDict;
    NSError *noError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noError];
    XCTAssertTrue(result);
    XCTAssertNil(noError);
}

- (void)testValidateUserInfoNoSecret {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    userInfo[kRemoteNotificationKeySecret] = nil;
    NSError *noSecretError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noSecretError];
    XCTAssertFalse(result);
    XCTAssertEqual(noSecretError.code, SFSDKPushNotificationErrorNoEncryptedSecret);
}

- (void)testValidateUserInfoNoContent {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    userInfo[kRemoteNotificationKeyContent] = nil;
    NSError *noContentError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noContentError];
    XCTAssertFalse(result);
    XCTAssertEqual(noContentError.code, SFSDKPushNotificationErrorNoEncryptedContent);
}

- (void)testValidateUserInfoNoTitle {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    NSMutableDictionary *apsDict = [userInfo[kRemoteNotificationKeyAps] mutableCopy];
    NSMutableDictionary *alertDict = [apsDict[kRemoteNotificationKeyAlert] mutableCopy];
    alertDict[kRemoteNotificationKeyTitle] = nil;
    apsDict[kRemoteNotificationKeyAlert] = alertDict;
    userInfo[kRemoteNotificationKeyAps] = apsDict;
   
    NSError *noTitleError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noTitleError];
    XCTAssertFalse(result);
    XCTAssertEqual(noTitleError.code, SFSDKPushNotificationErrorNoApsAlertTitle);
}

- (void)testValidateUserInfoNoBody {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    NSMutableDictionary *apsDict = [userInfo[kRemoteNotificationKeyAps] mutableCopy];
    NSMutableDictionary *alertDict = [apsDict[kRemoteNotificationKeyAlert] mutableCopy];
    alertDict[kRemoteNotificationKeyBody] = nil;
    apsDict[kRemoteNotificationKeyAlert] = alertDict;
    userInfo[kRemoteNotificationKeyAps] = apsDict;
    
    NSError *noBodyError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noBodyError];
    XCTAssertFalse(result);
    XCTAssertEqual(noBodyError.code, SFSDKPushNotificationErrorNoApsAlertBody);
}

- (void)testValidateUserInfoNoApsDict {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    userInfo[kRemoteNotificationKeyAps] = nil;
    NSError *noApsDictError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noApsDictError];
    XCTAssertFalse(result);
    XCTAssertEqual(noApsDictError.code, SFSDKPushNotificationErrorNoApsDictionary);
}

- (void)testValidateUserInfoNoApsAlertDict {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    NSMutableDictionary *apsDict = [userInfo[kRemoteNotificationKeyAps] mutableCopy];
    apsDict[kRemoteNotificationKeyAlert] = nil;
    userInfo[kRemoteNotificationKeyAps] = apsDict;
    NSError *noApsAlertDictError = nil;
    BOOL result = [SFSDKPushNotificationDecryption validateNotificationUserInfo:userInfo error:&noApsAlertDictError];
    XCTAssertFalse(result);
    XCTAssertEqual(noApsAlertDictError.code, SFSDKPushNotificationErrorNoApsAlertDictionary);
}

- (void)testNotificationNotEncrypted {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    
    // No 'encrypted' value.
    userInfo[kRemoteNotificationKeyEncrypted] = nil;
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *unexpectedError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&unexpectedError];
    XCTAssertTrue(result);
    XCTAssertNil(unexpectedError);
    
    // 'encrypted' value is set to NO.
    userInfo[kRemoteNotificationKeyEncrypted] = @NO;
    notifContent = [self notificationContentWithUserInfo:userInfo];
    unexpectedError = nil;
    result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&unexpectedError];
    XCTAssertTrue(result);
    XCTAssertNil(unexpectedError);
}

- (void)testNotificationTransform {
    NSError *unexpectedError = nil;
    UNMutableNotificationContent *contentNotif = [self notificationContentWithUserInfo:_userInfoDict];
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:contentNotif error:&unexpectedError];
    XCTAssertTrue(result);
    XCTAssertNil(unexpectedError);
    XCTAssertNil(contentNotif.userInfo[kRemoteNotificationKeyContent]);
    for (NSString *contentKey in _contentDict) {
        XCTAssertEqualObjects(_contentDict[contentKey], contentNotif.userInfo[contentKey]);
    }
    XCTAssertEqualObjects(contentNotif.title, _contentDict[kRemoteNotificationKeyAlertTitle]);
    XCTAssertEqualObjects(contentNotif.body, _contentDict[kRemoteNotificationKeyAlertBody]);
    XCTAssertEqualObjects(contentNotif.title, contentNotif.userInfo[kRemoteNotificationKeyAlertTitle]);
    XCTAssertEqualObjects(contentNotif.body, contentNotif.userInfo[kRemoteNotificationKeyAlertBody]);
}

- (void)testNotificationTransformMalformedSecret {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    userInfo[kRemoteNotificationKeySecret] = @"some not base64 string";
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *malformedSecretError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&malformedSecretError];
    XCTAssertFalse(result);
    XCTAssertEqual(malformedSecretError.code, SFSDKPushNotificationErrorMalformedSecretData);
}

- (void)testNotificationTransformNonRSASecret {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    NSString *nonRSASecretBase64 = [[@"some non-encrypted string" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    userInfo[kRemoteNotificationKeySecret] = nonRSASecretBase64;
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *nonRSASecretError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&nonRSASecretError];
    XCTAssertFalse(result);
    XCTAssertEqual(nonRSASecretError.code, SFSDKPushNotificationErrorSecretDecryptionFailed);
}

- (void)testNotificationTransformMalformedContent {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    userInfo[kRemoteNotificationKeyContent] = @"some not base64 string";
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *malformedContentError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&malformedContentError];
    XCTAssertFalse(result);
    XCTAssertEqual(malformedContentError.code, SFSDKPushNotificationErrorMalformedContentData);
}

- (void)testNotificationTransformNonAES128Content {
    NSMutableDictionary *userInfo = [_userInfoDict mutableCopy];
    NSString *nonAES128ContentBase64 = [[@"some non-encrypted string" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    userInfo[kRemoteNotificationKeyContent] = nonAES128ContentBase64;
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *nonAES128ContentError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&nonAES128ContentError];
    XCTAssertFalse(result);
    XCTAssertEqual(nonAES128ContentError.code, SFSDKPushNotificationErrorContentDecryptionFailed);
}

- (void)testNotificationTransformNonJSONContent {
    NSString *nonJSONContent = @"This is not JSON";
    SFSDKPushNotificationDataProvider *pndp = [[SFSDKPushNotificationDataProvider alloc] initWithContentJSON:nonJSONContent];
    NSDictionary *userInfo = pndp.userInfoDict;
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *nonJSONContentError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&nonJSONContentError];
    XCTAssertFalse(result);
    XCTAssertEqual(nonJSONContentError.code, SFSDKPushNotificationErrorInvalidContentFormat);
}

- (void)testNotificationTransformArrayJSONContent {
    NSString *arrayJSONContent = @"[ \"One\", \"Two\", \"Three\" ]";
    SFSDKPushNotificationDataProvider *pndp = [[SFSDKPushNotificationDataProvider alloc] initWithContentJSON:arrayJSONContent];
    NSDictionary *userInfo = pndp.userInfoDict;
    UNMutableNotificationContent *notifContent = [self notificationContentWithUserInfo:userInfo];
    NSError *arrayJSONContentError = nil;
    BOOL result = [SFSDKPushNotificationDecryption decryptNotificationContent:notifContent error:&arrayJSONContentError];
    XCTAssertFalse(result);
    XCTAssertEqual(arrayJSONContentError.code, SFSDKPushNotificationErrorInvalidContentFormat);
}

#pragma mark - Helper methods

- (nonnull UNMutableNotificationContent *)notificationContentWithUserInfo:(nonnull NSDictionary *)userInfo {
    UNMutableNotificationContent *mutContent = [[UNMutableNotificationContent alloc] init];
    mutContent.userInfo = userInfo;
    return mutContent;
}

@end

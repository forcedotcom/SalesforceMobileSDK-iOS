/* 
 * Copyright (c) 2013, salesforce.com, inc.
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

#import "SFRestAPI+Files.h"

#define ME @"me"
#define PAGE @"page"
#define VERSION @"versionNumber"
#define CONTENT_DOCUMENT_ID @"ContentDocumentId"
#define LINKED_ENTITY_ID @"LinkedEntityId"
#define SHARE_TYPE @"ShareType"
#define RENDITION_TYPE @"type"
#define FILE_DATA @"fileData"
#define TITLE @"title"
#define DESCRIPTION @"desc"

@implementation SFRestAPI (Files)

- (SFRestRequest *) requestForOwnedFilesList:(NSString *)userId page:(NSUInteger)page {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/users/%@", self.apiVersion, (userId == nil ? ME : userId)];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *) requestForFilesInUsersGroups:(NSString *)userId page:(NSUInteger)page {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/users/%@/filter/groups", self.apiVersion, (userId == nil ? ME : userId)];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *) requestForFilesSharedWithUser:(NSString *)userId page:(NSUInteger)page {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/users/%@/filter/sharedwithme", self.apiVersion, (userId == nil ? ME : userId)];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *) requestForFileDetails:(NSString *)sfdcId forVersion:(NSString *)version {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/%@", self.apiVersion, sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (version) params[VERSION] = version;
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *) requestForBatchFileDetails:(NSArray *)sfdcIds {
    NSString *ids = [sfdcIds componentsJoinedByString:@","];
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/batch/%@", self.apiVersion, ids];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *) requestForFileRendition:(NSString *)sfdcId version:(NSString *)version renditionType:(NSString *)renditionType page:(NSUInteger)page {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/%@/rendition", self.apiVersion, sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[RENDITION_TYPE] = renditionType;
    if (page) params[PAGE] = @(page);
    if (version) params[VERSION] = version;
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
    request.parseResponse = NO;
    return request;
}

- (SFRestRequest *) requestForFileContents:(NSString *) sfdcId version:(NSString*) version {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/%@/content", self.apiVersion, sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (version) params[VERSION] = version;
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
    request.parseResponse = NO;
    return request;
}

- (SFRestRequest *) requestForFileShares:(NSString *)sfdcId page:(NSUInteger)page {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/%@/file-shares", self.apiVersion, sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *) requestForAddFileShare:(NSString *)fileId entityId:(NSString *)entityId shareType:(NSString*)shareType {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/ContentDocumentLink", self.apiVersion];
    NSDictionary *params = @{CONTENT_DOCUMENT_ID: fileId, LINKED_ENTITY_ID: entityId, SHARE_TYPE: shareType};
    return [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:params];
}

- (SFRestRequest *) requestForDeleteFileShare:(NSString *)shareId {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/ContentDocumentLink/%@", self.apiVersion, shareId];
    return [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:nil];
}

- (SFRestRequest *) requestForUploadFile:(NSData *)data name:(NSString *)name description:(NSString *)description mimeType:(NSString *)mimeType {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/files/users/me", self.apiVersion];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (name) params[TITLE] = name;
    if (description) params[DESCRIPTION] = description;
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:params];
    [request addPostFileData:data paramName:FILE_DATA fileName:name mimeType:mimeType];
    return request;
}


@end

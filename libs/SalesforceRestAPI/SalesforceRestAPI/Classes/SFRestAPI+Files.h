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

#import <Foundation/Foundation.h>
#import "SFRestAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFRestAPI (Files) <SFRestDelegate>

/**
 * Build a Request that can fetch a page from the files owned by the
 * specified user.
 * 
 * @param userId if nil the context user is used, otherwise it should be an Id of a user.
 * @param page if nil fetches the first page, otherwise fetches the specified page.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForOwnedFilesList:(nullable NSString *)userId page:(NSUInteger)page;

/**
 * Build a Request that can fetch a page from the list of files from groups
 * that the user is a member of.
 * 
 * @param userId if nil the context user is used, otherwise it should be an Id of a user.
 * @param page if nil fetches the first page, otherwise fetches the specified page.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForFilesInUsersGroups:(nullable NSString *)userId page:(NSUInteger)page;

/**
 * Build a Request that can fetch a page from the list of files that have
 * been shared with the user.
 * 
 * @param userId if nil the context user is used, otherwise it should be an Id of a user.
 * @param page if nil fetches the first page, otherwise fetches the specified page.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForFilesSharedWithUser:(nullable NSString *)userId page:(NSUInteger)page;

/**
 * Build a Request that can fetch the file details of a particular version
 * of a file.
 * 
 * @param sfdcId The Id of the file
 * @param version if nil fetches the most recent version, otherwise fetches this specific version.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForFileDetails:(NSString *)sfdcId forVersion:(nullable NSString *)version;

/**
 * Build a request that can fetch the latest file details of one or more
 * files in a single request.
 * 
 * @param sfdcIds The list of file Ids to fetch.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForBatchFileDetails:(NSArray<NSString*> *)sfdcIds;

/**
 * Build a Request that can fetch the a preview/rendition of a particular
 * page of the file (and version)
 * 
 * @param sfdcId The Id of the file
 * @param version if nil fetches the most recent version, otherwise fetches this specific version
 * @param renditionType What format of rendition do you want to get
 * @param page which page to fetch, pages start at 0.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForFileRendition:(NSString *)sfdcId version:(nullable NSString *)version renditionType:(NSString *)renditionType page:(NSUInteger)page;

/**
 * Builds a request that can fetch the actual binary file contents of this
 * particular file.
 * 
 * @param sfdcId The Id of the file
 * @param version The version of the file
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForFileContents:(NSString *) sfdcId version:(nullable NSString*) version;

/**
 * Build a request that can fetch a page from the list of entities that this
 * file is shared to.
 * 
 * @param sfdcId The Id of the file.
 * @param page if nil fetches the first page, otherwise fetches the specified page.
 * @return A new SFRestRequest that can be used to fetch this data
 */
- (SFRestRequest *) requestForFileShares:(NSString *)sfdcId page:(NSUInteger)page;

/**
 * Build a request that will add a file share for the specified fileId to
 * the specified entityId
 * 
 * @param fileId the Id of the file being shared.
 * @param entityId the Id of the entity to share the file to (e.g. a user or a group)
 * @param shareType the type of share (V - View, C - Collaboration)
 * @return A new SFRestRequest that be can used to create this share.
 */
- (SFRestRequest *) requestForAddFileShare:(NSString *)fileId entityId:(NSString *)entityId shareType:(NSString*)shareType;

/**
 * Build a request that will delete the specified file share.
 * 
 * @param shareId The Id of the file share record (aka ContentDocumentLink)
 * @return A new SFRestRequest that can be used to delete this share
 */
- (SFRestRequest *) requestForDeleteFileShare:(NSString *)shareId;

/**
 * Build a request that can upload a new file to the server, this will
 * create a new file at version 1.
 * 
 * @param data Data to upload to the server.
 * @param name The name/title of this file.
 * @param description A description of the file.
 * @param mimeType The mime-type of the file, if known.
 * @return A SFRestRequest that can perform this upload.
 */
- (SFRestRequest *) requestForUploadFile:(NSData *)data name:(NSString *)name description:(NSString *)description mimeType:(NSString *)mimeType;

@end

NS_ASSUME_NONNULL_END

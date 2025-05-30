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

#import <Foundation/Foundation.h>
#import <MobileSyncExplorerCommon/SObjectDataSpec.h>
#import <MobileSyncExplorerCommon/SObjectData.h>

@import MobileSync;

@interface SObjectDataManager : NSObject

@property (nonatomic, readonly) SFSmartStore *store;
@property (nonatomic, strong) NSArray *dataRows;

- (id)initWithDataSpec:(SObjectDataSpec *)dataSpec;

- (void)refreshLocalData:(void (^)(void))completionBlock;
- (void)createLocalData:(SObjectData *)newData;
- (void)updateLocalData:(SObjectData *)updatedData;
- (void)deleteLocalData:(SObjectData *)dataToDelete;
- (void)undeleteLocalData:(SObjectData *)dataToDelete;
- (BOOL)dataHasLocalChanges:(SObjectData *)data;
- (BOOL)dataLocallyCreated:(SObjectData *)data;
- (BOOL)dataLocallyUpdated:(SObjectData *)data;
- (BOOL)dataLocallyDeleted:(SObjectData *)data;
- (void)refreshRemoteData:(void (^)(void))completionBlock;
- (void)updateRemoteData:(SFSyncSyncManagerUpdateBlock)completionBlock;
- (void)filterOnSearchTerm:(NSString *)searchTerm completion:(void (^)(void))completionBlock;
- (void)lastModifiedRecords:(int)limit completion:(void (^)(void))completionBlock;

@end

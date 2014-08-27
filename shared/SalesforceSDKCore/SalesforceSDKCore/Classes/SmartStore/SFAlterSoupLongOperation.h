/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

@class FMDatabaseQueue;
@class SFSmartStore;

// Enum for alter steps
typedef enum {
    SFAlterSoupStepStarting,
    SFAlterSoupStepRenameOldSoupTable,
    SFAlterSoupStepDropOldIndexes,
    SFAlterSoupStepRegisterSoupUsingTableName,
    SFAlterSoupStepCopyTable,
    SFAlterSoupStepReIndexSoup,
    SFAlterSoupStepDropOldTable
} SFAlterSoupStep;


// Fields of details for alter soup long operation row in long_operations_status table
static NSString * const SOUP_NAME       = @"soupName";
static NSString * const SOUP_TABLE_NAME = @"soupTableName";
static NSString * const OLD_INDEX_SPECS = @"oldIndexSpecs";
static NSString * const NEW_INDEX_SPECS = @"newIndexSpecs";
static NSString * const RE_INDEX_DATA   = @"reIndexData";
static NSInteger  const kLastStep = SFAlterSoupStepDropOldTable;


@interface SFAlterSoupLongOperation : NSObject {

}

// Soup being altered
@property (nonatomic, readonly, strong) NSString *soupName;

// Backing table for soup being altered
@property (nonatomic, readonly, strong) NSString *soupTableName;
	
// Last step completed
@property (nonatomic, readonly, assign) SFAlterSoupStep afterStep;
	
// New index specs
@property (nonatomic, readonly, strong) NSArray *indexSpecs;

// Old index specs
@property (nonatomic, readonly, strong) NSArray *oldIndexSpecs;

// True if soup elements should be brought to memory to be re-indexed
@property (nonatomic, readonly, assign) BOOL  reIndexData;
	
// Instance of smartstore
@property (nonatomic, readonly, strong) SFSmartStore *store;

// Underlying database
@property (nonatomic, readonly, strong) FMDatabaseQueue *queue;
	
// Row id for long_operations_status
@property (nonatomic, readonly, assign) long rowId;


/**
 Called when first running the alter soup
 @param store
 @param soupName
 @param newIndexSpecs
 @param reIndexData
 */
- (id) initWithStore:(SFSmartStore*)store soupName:(NSString*)soupName newIndexSpecs:(NSArray*)newIndexSpecs reIndexData:(BOOL)reIndexData;

/** 
 Called when resuming an alter soup operation from the data stored in the long operations status table
 @param store
 @param details
 @param status
*/
- (id) initWithStore:(SFSmartStore*) store rowId:(long) rowId details:(NSDictionary*)details status:(SFAlterSoupStep)status;

/**
 Run this operation
 */
- (void) run;

/**
 Run this operation up to a given step (used by tests)
 @param toStep
 */
- (void) runToStep:(SFAlterSoupStep) toStep;

@end


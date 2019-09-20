/*
 SFRestAPI+Instrumentation.m
 SalesforceSDKCore
 Created by Raj Rao on 3/21/19.
 
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


#import "SFSmartStore+Instrumentation.h"
#import <objc/runtime.h>
#import <os/log.h>
#import <os/signpost.h>
#import <SalesforceSDKCore/SFSDKInstrumentationHelper.h>
@interface SFSmartStore()
- (BOOL)firstTimeStoreDatabaseSetup;
- (BOOL)subsequentTimesStoreDatabaseSetup;
@end

@implementation SFSmartStore (Instrumentation)

+ (os_log_t)oslog {
    static os_log_t _logger;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        _logger = os_log_create([appName  cStringUsingEncoding:NSUTF8StringEncoding], [@"SFSmartStore" cStringUsingEncoding:NSUTF8StringEncoding]);
    });
    return _logger;
}


+ (void)load{
    if ([SFSDKInstrumentationHelper isEnabled] && (self == SFSmartStore.self)) {
        [self enableInstrumentation];
    }
}

+ (void)enableInstrumentation {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(attributesForSoup:);
        SEL swizzledSelector = @selector(instr_attributesForSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(indicesForSoup:);
        swizzledSelector = @selector(instr_indicesForSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(soupExists:);
        swizzledSelector = @selector(instr_soupExists:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(registerSoup:withIndexSpecs:error:);
        swizzledSelector = @selector(instr_registerSoup:withIndexSpecs:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(registerSoupWithSpec:withIndexSpecs:error:);
        swizzledSelector = @selector(instr_registerSoupWithSpec:withIndexSpecs:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(queryWithQuerySpec:pageIndex:error:);
        swizzledSelector = @selector(instr_queryWithQuerySpec:pageIndex:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(queryAsString:querySpec:pageIndex:error:);
        swizzledSelector = @selector(instr_queryAsString:querySpec:pageIndex:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(retrieveEntries:fromSoup:);
        swizzledSelector = @selector(instr_retrieveEntries:fromSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(upsertEntries:toSoup:);
        swizzledSelector = @selector(instr_upsertEntries:toSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];

        originalSelector = @selector(lookupSoupEntryIdForSoupName:forFieldPath:fieldValue:error:);
        swizzledSelector = @selector(instr_lookupSoupEntryIdForSoupName:forFieldPath:fieldValue:error:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(removeEntries:fromSoup:);
        swizzledSelector = @selector(instr_removeEntries:fromSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(removeEntriesByQuery:fromSoup:);
        swizzledSelector = @selector(instr_removeEntriesByQuery:fromSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(clearSoup:);
        swizzledSelector = @selector(instr_clearSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(removeSoup:);
        swizzledSelector = @selector(instr_removeSoup:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(removeAllSoups);
        swizzledSelector = @selector(instr_removeAllSoups);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(alterSoup:withIndexSpecs:reIndexData:);
        swizzledSelector = @selector(instr_alterSoup:withIndexSpecs:reIndexData:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(alterSoup:withSoupSpec:withIndexSpecs:reIndexData:);
        swizzledSelector = @selector(instr_alterSoup:withSoupSpec:withIndexSpecs:reIndexData:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(reIndexSoup:withIndexPaths:);
        swizzledSelector = @selector(instr_reIndexSoup:withIndexPaths:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(reIndexSoup:withIndexPaths:);
        swizzledSelector = @selector(instr_reIndexSoup:withIndexPaths:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(firstTimeStoreDatabaseSetup);
        swizzledSelector = @selector(instr_firstTimeStoreDatabaseSetup);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        originalSelector = @selector(subsequentTimesStoreDatabaseSetup);
        swizzledSelector = @selector(instr_subsequentTimesStoreDatabaseSetup);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        
        
    });
}

- (SFSoupSpec*)instr_attributesForSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "attributesForSoup", "storeName:%{public}@ soupName:%{public}@", self.storeName,soupName);
    SFSoupSpec *spec = [self instr_attributesForSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "attributesForSoup", "storeName:%{public}@  soupName:%{public}@", self.storeName,soupName);
    return  spec;
}

- (NSArray<SFSoupIndex*>*)instr_indicesForSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "indicesForSoup", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    NSArray<SFSoupIndex*>* indices = [self instr_indicesForSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "indicesForSoup", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return  indices;
}

- (BOOL)instr_soupExists:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "soupExists", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    BOOL soupExists = [self instr_soupExists:soupName];
    sf_os_signpost_interval_end(logger, sid, "soupExists", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return  soupExists;
}

- (BOOL)instr_registerSoup:(NSString*)soupName withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "registerSoup:withIndexSpecs:error", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    BOOL result = [self instr_registerSoup:soupName withIndexSpecs:indexSpecs error:error];
    sf_os_signpost_interval_end(logger, sid, "registerSoup:withIndexSpecs:error", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return  result;
}

- (BOOL)instr_registerSoupWithSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs error:(NSError**)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "registerSoupWithSpec:withIndexSpecs:error", "storeName:%{public}@  soupName:%{public}@", self.storeName, soupSpec.soupName);
    BOOL result = [self instr_registerSoupWithSpec:soupSpec withIndexSpecs:indexSpecs error:error];
    sf_os_signpost_interval_end(logger, sid, "registerSoupWithSpec:withIndexSpecs:error", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupSpec.soupName);
    return  result;
}

- (NSArray *)instr_queryWithQuerySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex error:(NSError **)error{
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "queryWithQuerySpec:pageIndex:error:", "storeName:%{public}@ soupName:%{public}@", self.storeName, querySpec.soupName);
    NSArray *result = [self instr_queryWithQuerySpec:querySpec pageIndex:pageIndex error:error];
    sf_os_signpost_interval_end(logger, sid, "queryWithQuerySpec:pageIndex:error:", "storeName:%{public}@ soupName:%{public}@", self.storeName, querySpec.soupName);
    return result;
}

- (BOOL)instr_queryAsString:(NSMutableString*)resultString querySpec:(SFQuerySpec *)querySpec pageIndex:(NSUInteger)pageIndex error:(NSError **)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "queryAsString:querySpec:pageIndex:error:", "storeName:%{public}@ soupName:%{public}@ query:%{public}@", self.storeName,  querySpec.soupName,resultString);
    BOOL result = [self instr_queryAsString:resultString querySpec:querySpec pageIndex:pageIndex error:error];
    sf_os_signpost_interval_end(logger, sid, "queryAsString:querySpec:pageIndex:error:", "storeName:%{public}@ soupName:%{public}@ query:%{public}@", self.storeName, querySpec.soupName,resultString);
    return result;
    
}

- (NSArray<NSDictionary*>*)instr_retrieveEntries:(NSArray<NSNumber*>*)soupEntryIds fromSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "retrieveEntries:fromSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    NSArray<NSDictionary*> *result = [self instr_retrieveEntries:soupEntryIds fromSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "retrieveEntries:fromSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (NSArray<NSDictionary*>*)instr_upsertEntries:(NSArray<NSDictionary*>*)entries toSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "upsertEntries", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    NSArray<NSDictionary*> *result = [self instr_upsertEntries:entries toSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "upsertEntries", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (NSArray *)instr_upsertEntries:(NSArray *)entries toSoup:(NSString *)soupName withExternalIdPath:(NSString *)externalIdPath error:(NSError **)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "upsertEntries:toSoup:withExternalIdPath:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    NSArray *result = [self instr_upsertEntries:entries toSoup:soupName withExternalIdPath:externalIdPath error:error];
    sf_os_signpost_interval_end(logger, sid, "upsertEntries:toSoup:withExternalIdPath:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (NSNumber *)instr_lookupSoupEntryIdForSoupName:(NSString *)soupName
                                         forFieldPath:(NSString *)fieldPath
                                           fieldValue:(NSString *)fieldValue
                                                error:(NSError **)error{
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "lookupSoupEntryIdForSoupName:forFieldPath:fieldValue:error:", "storeName:%{public}@  soupName:%{public}@ fieldPath:%{public}@ fieldValue:%{public}@", self.storeName, soupName,fieldPath,fieldValue);
    NSNumber *result = [self instr_lookupSoupEntryIdForSoupName:soupName forFieldPath:fieldPath fieldValue:fieldValue error:error];
    sf_os_signpost_interval_end(logger, sid, "lookupSoupEntryIdForSoupName:forFieldPath:fieldValue:error:", "storeName:%{public}@  soupName:%{public}@ fieldPath:%{public}@ fieldValue:%{public}@", self.storeName, soupName,fieldPath,fieldValue);
    return result;
}


- (void)instr_removeEntries:(NSArray<NSNumber*>*)entryIds fromSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "removeEntries:fromSoup:", "storeName:%{public}@  soupName:%{public}@ ", self.storeName, soupName);
    [self instr_removeEntries:entryIds fromSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "removeEntries:fromSoup:", "storeName:%{public}@  soupName:%{public}@", self.storeName, soupName);
}

- (BOOL)instr_removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName  error:(NSError **)error {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "removeEntries:fromSoup:error:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    BOOL result = [self instr_removeEntriesByQuery:querySpec fromSoup:soupName error:error];
    sf_os_signpost_interval_end(logger, sid, "removeEntries:fromSoup::error:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (void)instr_removeEntriesByQuery:(SFQuerySpec*)querySpec fromSoup:(NSString*)soupName{
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "removeEntriesByQuery:fromSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    [self instr_removeEntriesByQuery:querySpec fromSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "removeEntriesByQuery:fromSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
}

- (void)instr_clearSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "clearSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    [self instr_clearSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "clearSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
}

- (void)instr_removeSoup:(NSString*)soupName {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "removeSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    [self instr_removeSoup:soupName];
    sf_os_signpost_interval_end(logger, sid, "removeSoup:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
 }

- (void)instr_removeAllSoups {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "removeAllSoups:", "storeName:%{public}@",self.storeName);
    [self instr_removeAllSoups];
    sf_os_signpost_interval_end(logger, sid, "removeAllSoups:",  "storeName:%{public}@",self.storeName);
}

- (BOOL)instr_alterSoup:(NSString*)soupName withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs reIndexData:(BOOL)reIndexData {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "alterSoup:withIndexSpecs:reIndexData:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    BOOL result = [self instr_alterSoup:soupName withIndexSpecs:indexSpecs reIndexData:reIndexData];
    sf_os_signpost_interval_end(logger, sid, "alterSoup:withIndexSpecs:reIndexData:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (BOOL)instr_alterSoup:(NSString*)soupName withSoupSpec:(SFSoupSpec*)soupSpec withIndexSpecs:(NSArray<SFSoupIndex*>*)indexSpecs reIndexData:(BOOL)reIndexData{
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "alterSoup:withSoupSpec:withIndexSpecs:reIndexData:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    BOOL result = [self instr_alterSoup:soupName withSoupSpec:soupSpec withIndexSpecs:indexSpecs reIndexData:reIndexData];
    sf_os_signpost_interval_end(logger, sid, "alterSoup:withSoupSpec:withIndexSpecs:reIndexData:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (BOOL)instr_reIndexSoup:(NSString*)soupName withIndexPaths:(NSArray<NSString*>*)indexPaths {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "reIndexSoup:withIndexPaths:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    BOOL result = [self instr_reIndexSoup:soupName withIndexPaths:indexPaths];
    sf_os_signpost_interval_end(logger, sid, "reIndexSoup:withIndexPaths:", "storeName:%{public}@ soupName:%{public}@", self.storeName, soupName);
    return result;
}

- (BOOL)instr_firstTimeStoreDatabaseSetup {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "firstTimeStoreDatabaseSetup", "storeName:%{public}@",self.storeName);
    BOOL result = [self instr_firstTimeStoreDatabaseSetup];
    sf_os_signpost_interval_end(logger, sid, "firstTimeStoreDatabaseSetup", "storeName:%{public}@",self.storeName);
    return result;
    
}

- (BOOL)instr_subsequentTimesStoreDatabaseSetup {
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "subsequentTimesStoreDatabaseSetup", "storeName:%{public}@",self.storeName);
    BOOL result = [self instr_subsequentTimesStoreDatabaseSetup];
    sf_os_signpost_interval_end(logger, sid, "subsequentTimesStoreDatabaseSetup", "storeName:%{public}@",self.storeName);
    return result;
}
@end

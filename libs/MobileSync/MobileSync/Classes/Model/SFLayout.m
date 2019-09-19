/*
 SFLayout.m
 SmartSync
 
 Created by Bharath Hariharan on 5/17/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFLayout.h"

static NSString * const kSFId = @"id";
static NSString * const kSFLayoutType = @"layoutType";
static NSString * const kSFMode = @"mode";
static NSString * const kSFSections = @"sections";
static NSString * const kSFCollapsible = @"collapsible";
static NSString * const kSFColumns = @"columns";
static NSString * const kSFHeading = @"heading";
static NSString * const kSFLayoutRows = @"layoutRows";
static NSString * const kSFRows = @"rows";
static NSString * const kSFUseHeading = @"useHeading";
static NSString * const kSFLayoutItems = @"layoutItems";
static NSString * const kSFEditableForNew = @"editableForNew";
static NSString * const kSFEditableForUpdate = @"editableForUpdate";
static NSString * const kSFLabel = @"label";
static NSString * const kSFLayoutComponents = @"layoutComponents";
static NSString * const kSFLookupIdApiName = @"lookupIdApiName";
static NSString * const kSFRequired = @"required";
static NSString * const kSFSortable = @"sortable";

@interface SFLayout ()

@property (nonatomic, strong, readwrite) NSString *id;
@property (nonatomic, strong, readwrite) NSString *layoutType;
@property (nonatomic, strong, readwrite) NSString *mode;
@property (nonatomic, strong, readwrite) NSArray<SFLayoutSection *> *sections;
@property (nonatomic, strong, readwrite) NSDictionary *rawData;

@end

@implementation SFLayout

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFLayout *layout = nil;
    if (data) {
        layout = [[SFLayout alloc] init];
        layout.rawData = data;
        layout.id = data[kSFId];
        layout.layoutType = data[kSFLayoutType];
        layout.mode = data[kSFMode];
        NSArray *sections = data[kSFSections];
        NSMutableArray<SFLayoutSection *> *extractedSections = nil;
        if (sections) {
            extractedSections = [[NSMutableArray alloc] init];
            for (int i = 0; i < sections.count; i++) {
                NSDictionary *section = sections[i];
                if (section) {
                    [extractedSections addObject:[SFLayoutSection fromJSON:section]];
                }
            }
        }
        layout.sections = extractedSections;
    }
    return layout;
}

@end

@interface SFLayoutSection ()

@property (nonatomic, readwrite, assign) BOOL collapsible;
@property (nonatomic, strong, readwrite) NSNumber *columns;
@property (nonatomic, strong, readwrite) NSString *heading;
@property (nonatomic, strong, readwrite) NSString *id;
@property (nonatomic, strong, readwrite) NSArray<SFRow *> *layoutRows;
@property (nonatomic, strong, readwrite) NSNumber *rows;
@property (nonatomic, readwrite, assign) BOOL userHeading;

@end

@implementation SFLayoutSection

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFLayoutSection *layoutSection = nil;
    if (data) {
        layoutSection = [[SFLayoutSection alloc] init];
        layoutSection.collapsible = data[kSFCollapsible];
        layoutSection.columns = data[kSFColumns];
        layoutSection.heading = data[kSFHeading];
        layoutSection.id = data[kSFId];
        NSArray *rows = data[kSFLayoutRows];
        NSMutableArray<SFRow *> *extractedRows = nil;
        if (rows) {
            extractedRows = [[NSMutableArray alloc] init];
            for (int i = 0; i < rows.count; i++) {
                NSDictionary *row = rows[i];
                if (row) {
                    [extractedRows addObject:[SFRow fromJSON:row]];
                }
            }
        }
        layoutSection.layoutRows = extractedRows;
        layoutSection.rows = data[kSFRows];
        layoutSection.userHeading = data[kSFUseHeading];
    }
    return layoutSection;
}

@end

@interface SFRow ()

@property (nonatomic, strong, readwrite) NSArray<SFItem *> *layoutItems;

@end

@implementation SFRow

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFRow *row = nil;
    if (data) {
        row = [[SFRow alloc] init];
        NSArray *items = data[kSFLayoutItems];
        NSMutableArray<SFItem *> *extractedItems = nil;
        if (items) {
            extractedItems = [[NSMutableArray alloc] init];
            for (int i = 0; i < items.count; i++) {
                NSDictionary *item = items[i];
                if (item) {
                    [extractedItems addObject:[SFItem fromJSON:item]];
                }
            }
        }
        row.layoutItems = extractedItems;
    }
    return row;
}

@end

@interface SFItem ()

@property (nonatomic, readwrite, assign) BOOL editableForNew;
@property (nonatomic, readwrite, assign) BOOL editableForUpdate;
@property (nonatomic, strong, readwrite) NSString *label;
@property (nonatomic, strong, readwrite) NSDictionary *layoutComponents;
@property (nonatomic, strong, readwrite) NSString *lookupIdApiName;
@property (nonatomic, readwrite, assign) BOOL required;
@property (nonatomic, readwrite, assign) BOOL sortable;

@end

@implementation SFItem

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFItem *item = nil;
    if (data) {
        item = [[SFItem alloc] init];
        item.editableForNew = data[kSFEditableForNew];
        item.editableForUpdate = data[kSFEditableForUpdate];
        item.label = data[kSFLabel];
        item.layoutComponents = data[kSFLayoutComponents];
        item.lookupIdApiName = data[kSFLookupIdApiName];
        item.required = data[kSFRequired];
        item.sortable = data[kSFSortable];
    }
    return item;
}

@end

//
//  SFSharedInstancesManager.h
//  SalesforceCommonUtils
//
//  Created by João Neves on 8/24/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSharedInstancesManager : NSObject

// Whether or not `nil` can be used as a key.
// Default is YES
@property (nonatomic, assign) BOOL storesForNilKey;


- (id)instanceForKey:(id)key;

// The instance and the key will be retained.
- (void)setInstance:(id)instance forKey:(id)key;

// Removes both instance and key.
- (void)removeInstanceForKey:(id)key;

- (NSArray *)allKeys;

@end

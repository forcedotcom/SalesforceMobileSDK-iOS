//
//  SFOAuthCredentials+Internal.h
//  SalesforceOAuth
//
//  Created by Michael Nachbaur on 6/30/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "SFOAuthCredentials.h"


@interface SFOAuthCredentials ()

@property (nonatomic, readonly) NSMutableDictionary *tokenQuery;

- (void)initKeychainWithIdentifier:(NSString *)identifier accessGroup:(NSString *)accessGroup;
- (NSString *)tokenForKey:(NSString *)key;
- (NSMutableDictionary *)keychainItemWithConvertedTokenForMatchingItem:(NSDictionary *)matchDict;
- (NSMutableDictionary *)modelKeychainDictionaryForKey:(NSString *)key;
- (OSStatus)writeToKeychain:(NSMutableDictionary *)dictionary;

@end



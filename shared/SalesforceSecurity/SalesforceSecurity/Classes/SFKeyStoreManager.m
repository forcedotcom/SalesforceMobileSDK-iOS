//
//  SFKeyStoreManager
//  SalesforceSecurity
//
//  Created by Kevin Hawkins on 3/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFKeyStoreManager.h"
#import <SalesforceCommonUtils/SFKeychainItemWrapper.h>

NSString * const kSFKeyStoreManagerErrorDomain = @"com.salesforce.keystore.errorDomain";

static NSString * const kKeyStoreKeychainIdentifier = @"com.salesforce.keystore.keystoreKeychainId";
static NSString * const kKeyStoreDataArchiveKey = @"com.salesforce.keystore.keystoreDataArchive";

@interface SFKeyStoreManager ()

@property (nonatomic, strong) NSDictionary *keyStoreDictionary;

@end

@implementation SFKeyStoreManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static SFKeyStoreManager *keyStoreManager = nil;
    dispatch_once(&pred, ^{
		keyStoreManager = [[self alloc] init];
	});
    return keyStoreManager;
}

- (SFEncryptionKey *)retrieveKeyWithLabel:(NSString *)keyLabel
{
    if (keyLabel == nil) return nil;
    
    SFEncryptionKey *key = [self.keyStoreDictionary objectForKey:keyLabel];
#warning TODO: Decrypt key.
    return key;
}

- (void)storeKey:(SFEncryptionKey *)key withLabel:(NSString *)keyLabel
{
    NSAssert(key != nil, @"key must have a value.");
    NSAssert(keyLabel != nil, @"key label must have a value.");
    
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.keyStoreDictionary];
#warning TODO: Encrypt key.
    [mutableKeyStoreDict setObject:key forKey:keyLabel];
    self.keyStoreDictionary = mutableKeyStoreDict;
}

- (void)removeKeyWithLabel:(NSString *)keyLabel
{
    if (keyLabel == nil) return;
    
    NSMutableDictionary *mutableKeyStoreDict = [NSMutableDictionary dictionaryWithDictionary:self.keyStoreDictionary];
    [mutableKeyStoreDict removeObjectForKey:keyLabel];
    self.keyStoreDictionary = mutableKeyStoreDict;
}

- (BOOL)keyWithLabelExists:(NSString *)keyLabel
{
    SFEncryptionKey *key = [self retrieveKeyWithLabel:keyLabel];
    return (key != nil);
}

- (NSDictionary *)keyStoreDictionary
{
    @synchronized (self) {
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeyStoreKeychainIdentifier account:nil];
        NSData *keyStoreData = [keychainItem valueData];
        if (keyStoreData == nil) {
            return [NSDictionary dictionary];
        } else {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:keyStoreData];
            NSDictionary *keyStoreDict = [unarchiver decodeObjectForKey:kKeyStoreDataArchiveKey];
            [unarchiver finishDecoding];
            return keyStoreDict;
        }
    }
}

- (void)setKeyStoreDictionary:(NSDictionary *)keyStoreDictionary
{
    @synchronized (self) {
        SFKeychainItemWrapper *keychainItem = [[SFKeychainItemWrapper alloc] initWithIdentifier:kKeyStoreKeychainIdentifier account:nil];
        if (keyStoreDictionary == nil) {
            BOOL resetItemResult = [keychainItem resetKeychainItem];
            if (!resetItemResult) {
                [self log:SFLogLevelError msg:@"Error removing key store from the keychain."];
            }
        } else {
            NSMutableData *keyStoreData = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:keyStoreData];
            [archiver encodeObject:keyStoreDictionary forKey:kKeyStoreDataArchiveKey];
            [archiver finishEncoding];
            
            OSStatus saveKeyResult = [keychainItem setValueData:keyStoreData];
            if (saveKeyResult != noErr) {
                [self log:SFLogLevelError msg:@"Error saving key store to the keychain."];
            }
        }
    }
}

@end

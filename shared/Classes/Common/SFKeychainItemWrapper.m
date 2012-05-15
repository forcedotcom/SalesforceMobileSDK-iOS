//
//  CHKeychainItemWrapper.m
//  ChatterSDK
//
//  Created by Amol Prabhu on 1/11/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Security/Security.h>
#import "SFKeychainItemWrapper.h"
#import "SFCrypto.h"
#import "NSData+SFAdditions.h"
#import "NSString+SFAdditions.h"
#import "UIDevice-Hardware.h"
#import "SFLogger.h"

static NSString * const kRefreshTokenEncryptionKey = @"com.salesforce.oauth.refresh";

@interface SFKeychainItemWrapper ()
/*
 The method converts the data from the keychain wrapper class to what is expected by the keychain API
 */
- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert;
- (void)writeToKeychain;
- (void)setObject:(id)inObject forKey:(id)key;
@end

@implementation SFKeychainItemWrapper
@synthesize keychainData = _keychainData;
@synthesize encrypted = _encrypted;

- (id)initWithIdentifier:(NSString *)identifier account:(NSString *)account {
    if (self = [super init]) {
        
        _keychainQuery = [[NSMutableDictionary alloc] init];
		[_keychainQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
        [_keychainQuery setObject:identifier forKey:(id)kSecAttrService];
        if (account != nil) {
            [_keychainQuery setObject:account forKey:(id)kSecAttrAccount];
        }
        [_keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
        [_keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
        [_keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
        
        NSMutableDictionary *outDictionary = nil;
        if (! SecItemCopyMatching((CFDictionaryRef)_keychainQuery, (CFTypeRef *)&outDictionary) == noErr) {
            // Stick these default values into keychain item if nothing found.
            self.keychainData = [[[NSMutableDictionary alloc] init] autorelease];
            [self.keychainData setObject:identifier forKey:(id)kSecAttrService];
            if (account != nil) {
                [self.keychainData setObject:account forKey:(id)kSecAttrAccount];
            }
		}
        else {
            // load the saved data from Keychain.
            self.keychainData = [NSMutableDictionary dictionaryWithDictionary:outDictionary];
        }
        
		[outDictionary release];
    }
	return self;
}

- (void)dealloc {
    [_keychainData release]; _keychainData = nil;
    [_keychainQuery release]; _keychainQuery = nil;
	[super dealloc];
}

- (void)setObject:(id)inObject forKey:(id)key {
    if(inObject == nil) {
		[self.keychainData removeObjectForKey:key];
		[self writeToKeychain];
		return;
	} 
    id currentObject = [self.keychainData objectForKey:key];
    if (![currentObject isEqual:inObject]) {
		NSObject *inObjectCopy = [inObject copy];
		[self.keychainData setObject:inObjectCopy forKey:key];
		[inObjectCopy release];
		[self writeToKeychain];
	}
}

- (id)objectForKey:(id)key {
    return [[[self.keychainData objectForKey:key] copy] autorelease];
}

- (id)stringForKey:(id)key {
	NSObject *obj = [self objectForKey:key];
	if (obj == nil) { 
		return nil;
	}
	if ([obj isKindOfClass:[NSString class]]) {
		return (NSString *)obj;
	} else if([obj isKindOfClass:[NSData class]]) {
		NSString *s = [[NSString alloc] initWithData:(NSData *)obj
											encoding:NSUTF8StringEncoding];
		return [s autorelease];
	}
    
	return [NSString stringWithFormat:@"%@", obj];
}

- (BOOL)resetKeychainItem {
    OSStatus result = noErr;
    if (self.keychainData) {
        NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
        [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
        [query setObject:[_keychainQuery objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService]; 
        if ([_keychainQuery objectForKey:(id)kSecAttrAccount] ) {
            [query setObject:[_keychainQuery objectForKey:(id)kSecAttrAccount] forKey:(id)kSecAttrAccount];
        }
		result = SecItemDelete((CFDictionaryRef)query);
        if (noErr != result && errSecItemNotFound != result) {
            [self log:Info format:@"Error deleting keychain item: (%ld)", result];
        }
        [query release];
    }
    return noErr == result || errSecItemNotFound == result;
}

- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert {
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    [returnDictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [returnDictionary setObject:(id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly forKey:(id)kSecAttrAccessible];
    
    // Convert the NSString to NSData to meet the requirements for the value type kSecValueData.
    NSString *passwordString = [dictionaryToConvert objectForKey:(id)kSecValueData];
    if(passwordString != nil) {
		if ([passwordString isKindOfClass:[NSString class]]) {	
			[returnDictionary setObject:[(NSString *)passwordString dataUsingEncoding:NSUTF8StringEncoding]
								 forKey:(id)kSecValueData];
		} else {
			[returnDictionary setObject:passwordString
								 forKey:(id)kSecValueData];
		}
	}
    return returnDictionary;
}

- (void)writeToKeychain {
    NSDictionary *attributes = NULL;
    NSMutableDictionary *updateItem = NULL;
	OSStatus result;
    if (SecItemCopyMatching((CFDictionaryRef)_keychainQuery, (CFTypeRef *)&attributes) == noErr) {
        //found an exisiting item
        updateItem = [NSMutableDictionary dictionaryWithDictionary:attributes];
        [updateItem setObject:[_keychainQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
        
        NSMutableDictionary *tempCheck = [self dictionaryToSecItemFormat:self.keychainData];
        [tempCheck removeObjectForKey:(id)kSecClass];
        
        result = SecItemUpdate((CFDictionaryRef)updateItem, (CFDictionaryRef)tempCheck);
        if (noErr != result) {
            [self log:Error format:@"Error updating keychain item: (%ld)", result];
        }
    }
    else {
        // No previous item found; add the new one.
        result = SecItemAdd((CFDictionaryRef)[self dictionaryToSecItemFormat:self.keychainData], NULL);
        if (noErr != result) {
            [self log:Error format:@"Error adding keychain item: (%ld)", result];
        }
    }
    [attributes release]; // must release the _copy_ returned by ref
}

#pragma mark passcode methods

- (void)setPasscode:(NSString *)passcode {
    NSData *hashedData = [passcode sha256];
    NSString *strBaseEncode = [hashedData base64Encode];
	[self setObject:strBaseEncode forKey:(id)kSecValueData];
}

- (void)setHashedPasscode:(NSString *)passcode {
    [self setObject:passcode forKey:(id)kSecValueData];
}
- (NSString *)passcode {
	return [self stringForKey:(id)kSecValueData];
}

- (BOOL)verifyPasscode:(NSString *)passcode {
    NSString *strBaseEncode = [[passcode sha256] base64Encode];    
    NSString *passcodeString = [self passcode];
    
    if (passcodeString == nil) {
		[self log:Error msg:@"cannot verify password: passcode from keychain is nil"];
	}
    
    BOOL matches = [passcodeString isEqualToString:strBaseEncode];
	if (!matches) {
		[self log:Debug format:@"Passcode does not match!"];
	}       
    return matches;
}

#pragma mark ouath token methods

- (void)setToken:(NSData *)token{
    if (self.encrypted) {
        NSString *macAddress = [[UIDevice currentDevice] macaddress];
        NSString *strSecret = [macAddress stringByAppendingString:kRefreshTokenEncryptionKey];
        NSData *secretData = [strSecret sha256]; 
        
        SFCrypto *cipher = [[[SFCrypto alloc] initWithOperation:kCCEncrypt key:secretData mode:SFCryptoModeInMemory] autorelease];
        NSData *encryptedData = [cipher encryptDataInMemory:token];
        [self setObject:encryptedData forKey:(id)kSecValueData];
    } else {
        [self setObject:token forKey:(id)kSecValueData];
    }
}

- (NSData *)token {
    if (self.encrypted) {
        NSString *macAddress = [[UIDevice currentDevice] macaddress];
        NSString *strSecret = [macAddress stringByAppendingString:kRefreshTokenEncryptionKey];
        NSData *secretData = [strSecret sha256];
        
        SFCrypto *cipher  = [[[SFCrypto alloc] initWithOperation:kCCDecrypt key:secretData mode:SFCryptoModeInMemory] autorelease];
        return [cipher decryptDataInMemory:(NSData *)[self objectForKey:(id)kSecValueData]];
    } else {
        return (NSData *)[self objectForKey:(id)kSecValueData];
    }
}

- (NSData *)getToken {
    return [self token];
}

@end

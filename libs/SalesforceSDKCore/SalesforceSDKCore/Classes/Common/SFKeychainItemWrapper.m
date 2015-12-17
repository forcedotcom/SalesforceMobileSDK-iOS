/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

@import Security;

#import "SFKeychainItemWrapper+Internal.h"
#import "SFLogger.h"
#import "NSData+SFAdditions.h"
#import "NSString+SFAdditions.h"

@interface SFKeychainItemWrapper ()

@property (nonatomic, strong) NSMutableDictionary *keychainQuery;

@end

@implementation SFKeychainItemWrapper

// NSException constants
NSString * const kSFKeychainItemExceptionType         = @"com.salesforce.security.keychainException";
NSString * const kSFKeychainItemExceptionErrorCodeKey = @"com.salesforce.security.keychainException.errorCode";

// In-memory cache of keychain item wrapper (singleton) objects.
static NSMutableDictionary *sKeychainItemWrapperMap = nil;

// Whether keychain access exceptions should be considered fatal.  Default is YES.
static BOOL sKeychainAccessExceptionsAreFatal = YES;

// Static reference to the accessible attribute to use for all keychain item
static CFTypeRef sKeychainAccessibleAttribute;

#ifdef DEBUG
+ (void)dumpKeychain {
    NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
    
    [genericPasswordQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [genericPasswordQuery setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    [genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
    [genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    
    [self log:SFLogLevelDebug format:@"----- Keychain content ----------- "];
    
    NSArray *keychainItems = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)genericPasswordQuery, (CFTypeRef *)&keychainItems);
    if (status == noErr) {
        for (NSDictionary *keychainItem in (NSArray *)keychainItems) {
            [self log:SFLogLevelDebug format:@"- Keychain item:"];
            [self log:SFLogLevelDebug format:@"  Service: %@\n", [keychainItem objectForKey:(id)kSecAttrService]];
            [self log:SFLogLevelDebug format:@"  Account: %@\n", [keychainItem objectForKey:(id)kSecAttrAccount]];
            [self log:SFLogLevelDebug format:@"  Accessible: %@\n", [keychainItem objectForKey:(id)kSecAttrAccessible]];
            [self log:SFLogLevelDebug format:@"  Entitlement Group: %@\n", [keychainItem objectForKey:(id)kSecAttrAccessGroup]];
            [self log:SFLogLevelDebug format:@"  Data: %@\n", [keychainItem objectForKey:(id)kSecValueData]];
        }
        
    } else {
        [self log:SFLogLevelDebug format:@"** cannot read keychain: %ld", status];
    }
    [genericPasswordQuery release];
    [self log:SFLogLevelDebug format:@"---------------- "];
}
#endif

#pragma mark - Keychain item administration

+ (void)initialize {
    if (self == [SFKeychainItemWrapper class]) {
        sKeychainItemWrapperMap = [[NSMutableDictionary alloc] init];
        
        /// Initialize using the most restricted access
        sKeychainAccessibleAttribute = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    }
}

+ (SFKeychainItemWrapper *)itemWithIdentifier:(NSString *)identifier account:(NSString *)account {
    @synchronized (sKeychainItemWrapperMap) {
        NSString *itemDictKey = [self itemDictKeyForIdentifier:identifier account:account];
        SFKeychainItemWrapper *item = [sKeychainItemWrapperMap objectForKey:itemDictKey];
        if (!item) {
            item = [[[self alloc] initWithIdentifier:identifier account:account] autorelease];
            [sKeychainItemWrapperMap setObject:item forKey:itemDictKey];
        }
        return item;
    }
}

+ (NSString *)itemDictKeyForIdentifier:(NSString *)identifier account:(NSString *)account {
    return [NSString stringWithFormat:@"%@_%@", identifier, account];
}

- (instancetype)initWithIdentifier:(NSString *)identifier account:(NSString *)account {
    if (self = [super init]) {
        NSAssert(identifier != nil, @"identifier is a required value for a keychain item.");
        
        _keychainQuery = [[NSMutableDictionary alloc] init];
        [_keychainQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
        [_keychainQuery setObject:identifier forKey:(id)kSecAttrService];
        if (account) {
            [_keychainQuery setObject:account forKey:(id)kSecAttrAccount];
        }
        [_keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
        [_keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
        [_keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
        
        self.keychainData = [self dictionaryItemFromKeychain];
    }
	return self;
}

+ (void)resetInMemoryKeychainItems {
    @synchronized (sKeychainItemWrapperMap) {
        [sKeychainItemWrapperMap removeAllObjects];
    }
}

- (void)dealloc {
    [_keychainData release];
    [_keychainQuery release];
    _keychainData = nil;
    _keychainQuery = nil;
    [super dealloc];
}

+ (BOOL)keychainAccessErrorsAreFatal {
    return sKeychainAccessExceptionsAreFatal;
}

+ (void)setKeychainAccessErrorsAreFatal:(BOOL)errorsAreFatal {
    sKeychainAccessExceptionsAreFatal = errorsAreFatal;
}

+ (void)logAndThrowKeychainItemExceptionWithCode:(SFKeychainItemExceptionErrorCode)code msg:(NSString *)msg {
    [SFLogger log:self level:SFLogLevelError msg:msg];
    if ([self keychainAccessErrorsAreFatal]) {
        NSException *exception = [NSException exceptionWithName:kSFKeychainItemExceptionType reason:msg userInfo:@{ kSFKeychainItemExceptionErrorCodeKey: @(code) }];
        @throw exception;
    }
}

#pragma mark - Accessible Attribute

- (CFTypeRef)accessibleAttribute {
    return self.keychainData[(id)kSecAttrAccessible];
}

+ (void)setAccessibleAttribute:(CFTypeRef)accessibleAttribute {
    if (!CFEqual(sKeychainAccessibleAttribute, accessibleAttribute)) {
        [self log:SFLogLevelDebug format:@"Updating the keychain accessible attributes to be '%@' instead of '%@'", accessibleAttribute, sKeychainAccessibleAttribute];

        sKeychainAccessibleAttribute = accessibleAttribute;
        
        // Update all the items of the keychain
        [self updateKeychainAccessibleAttribute];
        
        // Force all keychain item to re-read their value from the keychain
        // so they pick up the new accessible attribute value.
        [self resetInMemoryKeychainItems];
    }
}

+ (void)updateKeychainAccessibleAttribute {
    NSMutableDictionary *genericPasswordQuery = [[NSMutableDictionary alloc] init];
    
    [genericPasswordQuery setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [genericPasswordQuery setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    [genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
    [genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    
    NSArray *keychainItems = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)genericPasswordQuery, (CFTypeRef *)&keychainItems);
    if (status == noErr) {
        for (NSDictionary *keychainItem in (NSArray *)keychainItems) {
            id accessibleAttribute = keychainItem[(id)kSecAttrAccessible];
            if (!accessibleAttribute || ![accessibleAttribute isEqual:sKeychainAccessibleAttribute]) {
                [self log:SFLogLevelDebug format:@"Updating item '%@-%@' from '%@' to '%@'", keychainItem[(id)kSecAttrService], keychainItem[(id)kSecAttrAccount], keychainItem[(id)kSecAttrAccessible], sKeychainAccessibleAttribute];
                
                NSMutableDictionary *query = [[[NSMutableDictionary alloc] init] autorelease];
                [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
                [query setObject:[keychainItem objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService];
                if ([keychainItem objectForKey:(id)kSecAttrAccount] ) {
                    [query setObject:[keychainItem objectForKey:(id)kSecAttrAccount] forKey:(id)kSecAttrAccount];
                }
                
                NSDictionary *updatedKeychainItem = @{ (id)kSecAttrAccessible : (id)sKeychainAccessibleAttribute, (id)kSecValueData : keychainItem[(id)kSecValueData] };
                
                OSStatus updateItemStatus = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)updatedKeychainItem);
                if (noErr != updateItemStatus) {
                    NSString *updateKeychainError = [NSString stringWithFormat:@"%@: Error updating keychain item: %@.", NSStringFromSelector(_cmd), [[self class] keychainErrorCodeString:updateItemStatus]];
                    [[self class] logAndThrowKeychainItemExceptionWithCode:SFKeychainItemExceptionKeychainInaccessible msg:updateKeychainError];
                }
            }
        }
    } else {
        [self log:SFLogLevelError format:@"cannot read the keychain: %ld", status];
    }
    [genericPasswordQuery release];
    [keychainItems release];
}

#pragma mark - Keychain access methods

- (NSMutableDictionary *)dictionaryItemFromKeychain {
    NSMutableDictionary *keychainOutDictionary = nil;
    NSMutableDictionary *returnDictionary;
    
    OSStatus copyMatchingStatus = SecItemCopyMatching((CFDictionaryRef)self.keychainQuery, (CFTypeRef *)&keychainOutDictionary);
    if (copyMatchingStatus != noErr) {
        // If it's not a "not found" error, report that.
        if (copyMatchingStatus != errSecItemNotFound) {
            NSString *copyMatchingError = [NSString stringWithFormat:@"%@: Error attempting to look up keychain item: %@", NSStringFromSelector(_cmd), [[self class] keychainErrorCodeString:copyMatchingStatus]];
            [[self class] logAndThrowKeychainItemExceptionWithCode:SFKeychainItemExceptionKeychainInaccessible msg:copyMatchingError];
        }
        
        // Stick these default values into keychain item if nothing found.
        returnDictionary = [NSMutableDictionary dictionary];
        NSString *identifier = [self.keychainQuery objectForKey:(id)kSecAttrService];
        if (identifier)
            [returnDictionary setObject:identifier forKey:(id)kSecAttrService];
        NSString *account = [self.keychainQuery objectForKey:(id)kSecAttrAccount];
        if (account) {
            [returnDictionary setObject:account forKey:(id)kSecAttrAccount];
        }
    } else {
        // Found data in the keychain.  We'll use that.
        returnDictionary = [NSMutableDictionary dictionaryWithDictionary:keychainOutDictionary];
    }
    
    [keychainOutDictionary release];
    return returnDictionary;
}

- (OSStatus)setObject:(id)inObject forKey:(id)key {
    @synchronized (self) {
        if(!inObject || inObject == [NSNull null]) {
            // TODO: This probably isn't working as intended.  This is currently essentially a no-op.  Should probably be refactored.
            [self.keychainData removeObjectForKey:key];
            return [self writeToKeychain];
        }
        id currentObject = [self.keychainData objectForKey:key];
        if (![currentObject isEqual:inObject]) {
            id inObjectCopy = [inObject copy];
            [self.keychainData setObject:inObjectCopy forKey:key];
            [inObjectCopy release];
            
            OSStatus writeResult = [self writeToKeychain];
            if (writeResult != noErr) {
                // Revert to the original value, keep the in-memory and keychain value synced.
                if (currentObject) {
                    [self.keychainData setObject:currentObject forKey:key];
                }
                NSString *saveToKeychainError = [NSString stringWithFormat:@"%@: Error saving value to the keychain: %@.", NSStringFromSelector(_cmd), [[self class] keychainErrorCodeString:writeResult]];
                [[self class] logAndThrowKeychainItemExceptionWithCode:SFKeychainItemExceptionKeychainInaccessible msg:saveToKeychainError];
            }
            return writeResult;
        } else {
            [self log:SFLogLevelDebug msg:@"setObject:forKey: Value already stored in the keychain. No action taken."];
            return noErr;
        }
    }
}

- (id)objectForKey:(id)key {
    @synchronized (self) {
        return [[[self.keychainData objectForKey:key] copy] autorelease];
    }
}

- (id)stringForKey:(id)key {
    @synchronized (self) {
        id obj = [self objectForKey:key];
        if (!obj) {
            return nil;
        }
        if ([obj isKindOfClass:[NSString class]]) {
            return (NSString *)obj;
        } else if ([obj isKindOfClass:[NSData class]]) {
            NSString *s = [[NSString alloc] initWithData:(NSData *)obj
                                                encoding:NSUTF8StringEncoding];
            return [s autorelease];
        }
        
        return [NSString stringWithFormat:@"%@", obj];
    }
}

- (BOOL)resetKeychainItem {
    @synchronized ([self class]) {
        OSStatus result = noErr;
        if (self.keychainData) {
            NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
            [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
            [query setObject:[self.keychainQuery objectForKey:(id)kSecAttrService] forKey:(id)kSecAttrService];
            if ([self.keychainQuery objectForKey:(id)kSecAttrAccount] ) {
                [query setObject:[self.keychainQuery objectForKey:(id)kSecAttrAccount] forKey:(id)kSecAttrAccount];
            }
            result = SecItemDelete((CFDictionaryRef)query);
            if (noErr != result && errSecItemNotFound != result) {
                NSString *deleteFromKeychainError = [NSString stringWithFormat:@"%@: Error deleting keychain item: %@.", NSStringFromSelector(_cmd), [[self class] keychainErrorCodeString:result]];
                [[self class] logAndThrowKeychainItemExceptionWithCode:SFKeychainItemExceptionKeychainInaccessible msg:deleteFromKeychainError];
            } else {
                self.keychainData = [self dictionaryItemFromKeychain];
            }
            [query release];
        }
        return noErr == result || errSecItemNotFound == result;
    }
}

- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert {
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    [returnDictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [returnDictionary setObject:(id)sKeychainAccessibleAttribute forKey:(id)kSecAttrAccessible];
    
    // Convert the NSString to NSData to meet the requirements for the value type kSecValueData.
    NSString *passwordString = [dictionaryToConvert objectForKey:(id)kSecValueData];
    if(passwordString) {
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

- (OSStatus)writeToKeychain {
    @synchronized ([self class]) {
        NSDictionary *attributes = NULL;
        NSMutableDictionary *query = NULL;
        OSStatus result;
        if (SecItemCopyMatching((CFDictionaryRef)self.keychainQuery, (CFTypeRef *)&attributes) == noErr) {
            // Found an existing item.
            query = [NSMutableDictionary dictionaryWithDictionary:attributes];
            [query setObject:[self.keychainQuery objectForKey:(id)kSecClass] forKey:(id)kSecClass];
            
            NSMutableDictionary *newDictionary = [self dictionaryToSecItemFormat:self.keychainData];
            [newDictionary removeObjectForKey:(id)kSecClass];
            [newDictionary removeObjectForKey:(id)kSecAttrAccessControl];
            [query removeObjectForKey:(id)kSecAttrAccessControl];
            
            result = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)newDictionary);
            if (noErr != result) {
                NSString *updateKeychainError = [NSString stringWithFormat:@"%@: Error updating keychain item: %@.", NSStringFromSelector(_cmd), [[self class] keychainErrorCodeString:result]];
                [[self class] logAndThrowKeychainItemExceptionWithCode:SFKeychainItemExceptionKeychainInaccessible msg:updateKeychainError];
            }
        }
        else {
            // No previous item found; add the new one.
            result = SecItemAdd((CFDictionaryRef)[self dictionaryToSecItemFormat:self.keychainData], NULL);
            if (noErr != result) {
                NSString *addToKeychainError = [NSString stringWithFormat:@"%@: Error adding keychain item: %@.", NSStringFromSelector(_cmd), [[self class] keychainErrorCodeString:result]];
                [[self class] logAndThrowKeychainItemExceptionWithCode:SFKeychainItemExceptionKeychainInaccessible msg:addToKeychainError];
            }
        }
        [attributes release]; // must release the _copy_ returned by ref
        
        // Don't forget to update the accessible attribute used during
        // the write operation so the in-memory data reflects that.
        self.keychainData[(id)kSecAttrAccessible] = sKeychainAccessibleAttribute;

        return result;
    }
}

+ (NSString *)keychainErrorCodeString:(OSStatus)errorCode {
    switch (errorCode) {
        case errSecSuccess:
            return @"errSecSuccess";
        case errSecUnimplemented:
            return @"errSecUnimplemented";
        case errSecParam:
            return @"errSecParam";
        case errSecAllocate:
            return @"errSecAllocate";
        case errSecNotAvailable:
            return @"errSecNotAvailable";
        case errSecAuthFailed:
            return @"errSecAuthFailed";
        case errSecDuplicateItem:
            return @"errSecDuplicateItem";
        case errSecItemNotFound:
            return @"errSecItemNotFound";
        case errSecInteractionNotAllowed:
            return @"errSecInteractionNotAllowed";
        case errSecDecode:
            return @"errSecDecode";
        default:
            return [NSString stringWithFormat:@"Unknown status code (%d)", (int)errorCode];
    }
}

#pragma mark generic data storage and retrieval methods

- (OSStatus)setValueData:(NSData *)data {
    @synchronized (self) {
        return [self setObject:data forKey:(id)kSecValueData];
    }
}

- (NSData *)valueData {
    @synchronized (self) {
        return (NSData *)[self objectForKey:(id)kSecValueData];
    }
}

#pragma mark passcode methods

- (void)setPasscode:(NSString *)passcode {
    @synchronized (self) {
        NSData *hashedData = [passcode sha256];
        NSString *strBaseEncode = [hashedData base64Encode];
        [self setObject:strBaseEncode forKey:(id)kSecValueData];
    }
}

- (NSString *)passcode {
    @synchronized (self) {
        return [self stringForKey:(id)kSecValueData];
    }
}

- (BOOL)verifyPasscode:(NSString *)passcode {
    NSString *strBaseEncode = [[passcode sha256] base64Encode];    
    NSString *passcodeString = [self passcode];
    
    if (!passcodeString) {
		[self log:SFLogLevelError msg:@"cannot verify password: passcode from keychain is nil"];
	}
    
    BOOL matches = [passcodeString isEqualToString:strBaseEncode];
	if (!matches) {
		[self log:SFLogLevelDebug format:@"Passcode does not match!"];
	}       
    return matches;
}

@end

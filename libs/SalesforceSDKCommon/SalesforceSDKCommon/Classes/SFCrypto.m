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

#import "SFCrypto.h"
#import "SFCrypto+Internal.h"
#import "NSString+SFAdditions.h"
#import "NSData+SFAdditions.h"
#import "SFKeychainItemWrapper.h"
#import "SFLogger.h"

static NSString * const kKeychainIdentifierPasscode = @"com.salesforce.security.passcode";
static NSString * const kKeychainIdentifierIV = @"com.salesforce.security.IV";

NSString * const kKeychainIdentifierBaseAppId = @"com.salesforce.security.baseappid";

@implementation SFCrypto

@synthesize status = _status;
@synthesize outputStream = _outputStream;
@synthesize file = _file;
@synthesize dataBuffer = _dataBuffer;
@synthesize mode = _mode;

#pragma mark - Object Lifecycle

- (id)initWithOperation:(SFCryptoOperation)operation key:(NSData *)key iv:(NSData*)iv mode:(SFCryptoMode)mode {
    if (self = [super init]) {
        char keyPtr[kCCKeySizeAES256 + 1];
        bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)

        // Fetch key data
        [key getBytes:keyPtr length:sizeof(keyPtr)];
        if (!iv) {
            iv = [self initializationVector];
        }
        CCOperation cryptoOperation = (operation == SFCryptoOperationEncrypt) ? kCCEncrypt : kCCDecrypt;
        CCCryptorStatus cryptStatus = CCCryptorCreate(cryptoOperation, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                                      keyPtr, kCCKeySizeAES256,
                                                      [iv bytes],
                                                      &_cryptor);
        if (cryptStatus != kCCSuccess) {
            [self log:SFLogLevelError format:@"cryptor creation failure (%d)", cryptStatus];
            return nil;
        }
        
        _mode = mode;
        if (mode == SFCryptoModeInMemory) {
            _dataBuffer = [[NSMutableData alloc] init];
        }
    }
    return self;
}

- (id)initWithOperation:(SFCryptoOperation)operation key:(NSData *)key mode:(SFCryptoMode)mode{
    return [self initWithOperation:operation key:key iv:nil mode:mode];
}

- (void)setFile:(NSString *)file {
    if (file && file != _file) {
        [self willChangeValueForKey:@"file"];
        _file = [file copy];
        if (_outputStream) {
            [_outputStream close];
        }
        _outputStream = [NSOutputStream outputStreamToFileAtPath:_file append:YES];
        [_outputStream open];
        [self didChangeValueForKey:@"file"];
    }
}

- (void)dealloc {
    if (_outputStream) {
        [_outputStream close];
    }
}

#pragma mark - Implementation

+ (BOOL)hasInitializationVector {
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierIV account:nil];
    NSData *iv = [keychainWrapper valueData];
    if (iv) {
        return YES;
    }
    return NO;
}

- (NSData *)initializationVector {
    SFKeychainItemWrapper *keychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierIV account:nil];
    NSData *iv = [keychainWrapper valueData];
    if (iv) {
        return iv;
    } else {
        NSMutableData *data = [NSMutableData dataWithLength:kCCBlockSizeAES128];
        iv = [data randomDataOfLength:kCCBlockSizeAES128];
        [keychainWrapper setValueData:iv];
        return iv;
    }
}

+ (NSData *)secretWithKey:(NSString *)key {
    SFKeychainItemWrapper *passcodeWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierPasscode account:nil];
    NSString *passcode = [passcodeWrapper passcode];
    
    NSString *baseAppId = [self baseAppIdentifier];
    NSString *strSecret = [baseAppId stringByAppendingString:key];
    if (passcode) {
        strSecret = [strSecret stringByAppendingString:passcode];
    }
    
    NSData *secretData = [strSecret sha256]; 
    return secretData;
}

+ (BOOL)baseAppIdentifierIsConfigured {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kKeychainIdentifierBaseAppId];
}

+ (void)setBaseAppIdentifierIsConfigured:(BOOL)isConfigured {
    [[NSUserDefaults standardUserDefaults] setBool:isConfigured forKey:kKeychainIdentifierBaseAppId];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static BOOL sBaseAppIdConfiguredThisLaunch = NO;
+ (BOOL)baseAppIdentifierConfiguredThisLaunch {
    return sBaseAppIdConfiguredThisLaunch;
}
+ (void)setBaseAppIdentifierConfiguredThisLaunch:(BOOL)configuredThisLaunch {
    sBaseAppIdConfiguredThisLaunch = configuredThisLaunch;
}

+ (NSString *)baseAppIdentifier {
    static NSString *baseAppId = nil;
    
    @synchronized (self) {
        BOOL hasBaseAppId = [self baseAppIdentifierIsConfigured];
        if (!hasBaseAppId) {
            // Value hasn't yet been (successfully) persisted to the keychain.
            [SFLogger log:self level:SFLogLevelInfo msg:@"Base app identifier not configured.  Creating a new value."];
            if (baseAppId == nil)
                baseAppId = [[NSUUID UUID] UUIDString];
            BOOL creationSuccess = [self setBaseAppIdentifier:baseAppId];
            if (!creationSuccess) {
                [SFLogger log:self level:SFLogLevelError msg:@"Could not persist the base app identifier.  Returning in-memory value."];
            } else {
                [self setBaseAppIdentifierIsConfigured:YES];
                [self setBaseAppIdentifierConfiguredThisLaunch:YES];
            }
        } else {
            // A value has been successfully persisted to the keychain.  Attempt to retrieve it.
            SFKeychainItemWrapper *baseAppIdKeychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierBaseAppId account:nil];
            NSData *keychainAppIdData = [baseAppIdKeychainWrapper valueData];
            NSString *keychainAppId = [[NSString alloc] initWithData:keychainAppIdData encoding:NSUTF8StringEncoding];
            if (keychainAppIdData == nil || keychainAppId == nil) {
                // Something went wrong either storing or retrieving the value from the keychain.  Try to rewrite the value.
                [SFLogger log:self level:SFLogLevelError msg:@"App id keychain data missing or corrupted.  Attempting to reset."];
                [self setBaseAppIdentifierIsConfigured:NO];
                [self setBaseAppIdentifierConfiguredThisLaunch:NO];
                if (baseAppId == nil)
                    baseAppId = [[NSUUID UUID] UUIDString];
                BOOL creationSuccess = [self setBaseAppIdentifier:baseAppId];
                if (!creationSuccess) {
                    [SFLogger log:self level:SFLogLevelError msg:@"Could not persist the base app identifier.  Returning in-memory value."];
                } else {
                    [self setBaseAppIdentifierIsConfigured:YES];
                    [self setBaseAppIdentifierConfiguredThisLaunch:YES];
                }
            } else {
                // Successfully retrieved the value.  Set the baseAppId accordingly.
                baseAppId = keychainAppId;
            }
        }
        
        return baseAppId;
    }
}

+ (BOOL)setBaseAppIdentifier:(NSString *)appId {
    static NSUInteger maxRetries = 3;
    
    // Store the app ID value in the keychain.
    [SFLogger log:self level:SFLogLevelInfo msg:@"Saving the new base app identifier to the keychain."];
    SFKeychainItemWrapper *baseAppIdKeychainWrapper = [SFKeychainItemWrapper itemWithIdentifier:kKeychainIdentifierBaseAppId account:nil];
    NSUInteger currentRetries = 0;
    OSStatus keychainResult = -1;
    NSData *appIdData = [appId dataUsingEncoding:NSUTF8StringEncoding];
    while (currentRetries < maxRetries && keychainResult != noErr) {
        keychainResult = [baseAppIdKeychainWrapper setValueData:appIdData];
        if (keychainResult != noErr) {
            [SFLogger log:self
                    level:SFLogLevelWarning
                   format:@"Could not save the base app identifier to the keychain (result: %@).  Retrying.", [SFKeychainItemWrapper keychainErrorCodeString:keychainResult]];
        }
        currentRetries++;
    }
    if (keychainResult != noErr) {
        [SFLogger log:self
                level:SFLogLevelError
               format:@"Giving up on saving the base app identifier to the keychain (result: %@).", [SFKeychainItemWrapper keychainErrorCodeString:keychainResult]];
        return NO;
    }
    
    [SFLogger log:self level:SFLogLevelInfo msg:@"Successfully created a new base app identifier and stored it in the keychain."];
    return YES;
}

- (void)cryptData:(NSData *)inData {
    if (inData) {
        size_t outLength = CCCryptorGetOutputLength(_cryptor, (size_t)[inData length], TRUE); // TRUE == final, i.e. include pad bytes
        uint8_t *outBuffer = calloc(outLength, sizeof(uint8_t));
        size_t dataOutMoved = 0;
        
        CCCryptorStatus status = CCCryptorUpdate(_cryptor, [inData bytes], (size_t)[inData length], outBuffer, outLength, &dataOutMoved);
        if (status == kCCSuccess) {
            [self appendToBuffer:[NSData dataWithBytesNoCopy:outBuffer length:dataOutMoved freeWhenDone:NO]]; // we free outBuffer explicity below
        } else {
            [self log:SFLogLevelError format:@"cryptor update failure (%d) - no data written", status];
        }
        free(outBuffer); outBuffer = NULL;
    }
}

- (BOOL)finalizeCipher {
    size_t outLength = kCCBlockSizeAES128; // worst case max buffer size for finalization is 1 full block
    uint8_t *outBuffer = calloc(outLength, sizeof(uint8_t));
    size_t dataOutMoved = 0;
    
    CCCryptorStatus status = CCCryptorFinal(_cryptor, outBuffer, outLength, &dataOutMoved);
    if (kCCSuccess == status) {
        [self appendToBuffer:[NSData dataWithBytesNoCopy:outBuffer length:dataOutMoved freeWhenDone:NO]]; // we free outBuffer explicity below
    } else {
        [self log:SFLogLevelError format:@"cryptor finalization failure (%d) - final data not written", status];
    }
    
    free(outBuffer); outBuffer = NULL;
    CCCryptorRelease(_cryptor); _cryptor = NULL;
    [self.outputStream close];
    return (kCCSuccess == status);
}


- (void)appendToBuffer:(NSData *)data {
    if (![data length]) return;
    
    if (SFCryptoModeInMemory == self.mode) {
        [self.dataBuffer appendData:data];
    } else { // CHCryptoModeDisk
        NSInteger result = [self.outputStream write:[data bytes] maxLength:[data length]];
        if (!result) {
            [self log:SFLogLevelError format:@"failed to write crypted data to output stream (%d)", result];
        }
    }
}

- (NSData *)decryptDataInMemory:(NSData *)data {
    NSData *decryptedData = nil;
    if (data) {
        [self cryptData:data];
        [self finalizeCipher];
        decryptedData = [NSData dataWithData:self.dataBuffer];
    }
    return decryptedData;
}

- (NSData *)encryptDataInMemory:(NSData *)data {
    NSData *encryptedData = nil;
    if (data) {
        [self cryptData:data];
        [self finalizeCipher];
        encryptedData = [NSData dataWithData:self.dataBuffer];
    }
    return encryptedData;
}

-(BOOL) decrypt:(NSString *)inputFile to:(NSString *)outputFile {
    FILE *source = fopen([inputFile UTF8String], "rb");
    if (!source) {
        [self log:SFLogLevelError format:@"failed to read input file"];
        return NO;
    }
    
    FILE *destination = fopen([outputFile UTF8String], "wb");
    if (!destination) {
        [self log:SFLogLevelError format:@"failed to write output file"];
        fclose(source);
        return NO;
    }
    
    const size_t bufferSize = 256*1024; // block size to read
    unsigned char buffer[bufferSize];
    const size_t decryptBufferSize = bufferSize + 16;
    uint8_t *outBuffer = calloc(decryptBufferSize, sizeof(uint8_t));
    size_t bytesToWrite = 0;
    size_t outLength;
    CCCryptorStatus status = -1;
    
    size_t bytesRead;
    while ((bytesRead = fread(buffer, 1, bufferSize, source)) > 0) {
        outLength = CCCryptorGetOutputLength(_cryptor, bytesRead, TRUE); // TRUE == final, i.e. include pad bytes
        status = CCCryptorUpdate(_cryptor, buffer, bytesRead, outBuffer, outLength, &bytesToWrite);
        if (status == kCCSuccess) {
            fwrite(outBuffer, 1, bytesToWrite, destination);
        } else {
            [self log:SFLogLevelError format:@"decrypt failure (%d) - no data written", status];
            break;
        }
        memset(outBuffer, 0, decryptBufferSize);
    }
    
    if (status == kCCSuccess) {
        outLength = kCCBlockSizeAES128; // worst case max buffer size for finalization is 1 full block
        bytesToWrite = 0;
        memset(outBuffer, 0, decryptBufferSize);
    
        CCCryptorStatus status = CCCryptorFinal(_cryptor, outBuffer, outLength, &bytesToWrite);
        if (kCCSuccess == status) {
            fwrite(outBuffer, 1, bytesToWrite, destination);
        } else {
            [self log:SFLogLevelError format:@"decrypt finalization failure (%d) - final data not written", status];
        }
    }
    
    free(outBuffer);
    outBuffer = NULL;
    CCCryptorRelease(_cryptor);
    _cryptor = NULL;

    fclose(source);
    fclose(destination);

    return (kCCSuccess == status);
}

@end
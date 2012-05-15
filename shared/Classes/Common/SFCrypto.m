//
//  CHCrypto.m
//  ChatterSDK
//
//  Created by Amol Prabhu on 1/11/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "SFCrypto.h"
#import "UIDevice-Hardware.h"
#import "CHKeychainItemWrapper.h"
#import "NSString+Additions.h"

static const char *const_key = "SFDCMobileChatteriOS";
static NSString * const kKeychainIdentifierPasscode = @"com.salesforce.security.passcode";

@interface CHCrypto ()
@property (nonatomic) CCCryptorStatus status;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic, copy) NSMutableData *dataBuffer;
- (NSData *)defaultSecret;
@end


@implementation CHCrypto

@synthesize status = _status;
@synthesize outputStream = _outputStream;
@synthesize file = _file;
@synthesize dataBuffer = _dataBuffer;
@synthesize mode = _mode;

#pragma mark - Object Lifecycle
- (id)initWithOperation:(CCOperation)operation key:(NSData *)key mode:(CHCryptoMode)mode{
    if (self = [super init]) {
        char keyPtr[kCCKeySizeAES256 + 1];
        bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
        
        // Fetch key data
        if (!key) {
            NSData *secret = [self defaultSecret];
            [secret getBytes:keyPtr length:sizeof(keyPtr)];
        } else {
            [key getBytes:keyPtr length:sizeof(keyPtr)];
        }
        
        CCCryptorStatus cryptStatus = CCCryptorCreate(operation, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                                      keyPtr, kCCKeySizeAES256,
                                                      NULL,
                                                      &_cryptor);
        
        if (cryptStatus != kCCSuccess) {
            return nil;
        }
        _totalLength = 0; // Keeps track of the total length of the output buffer
        _filePtr = 0;   // Maintains the file pointer for the output buffer
        
        _mode = mode;
        
        if (mode == CHCryptoModeInMemory) {
            _dataBuffer = [[NSMutableData alloc] init];
        }
        
    }
    return self;
}

-(void)setFile:(NSString *)file {
    if (file && file != _file) {
        [_file release];
        [self willChangeValueForKey:@"file"];
        _file = [file copy];
        if (_outputStream) {
            [_outputStream close];
            CHRelease(_outputStream);
        }
        _outputStream = [[NSOutputStream outputStreamToFileAtPath:_file append:YES] retain];
        [_outputStream open];
        [self didChangeValueForKey:@"file"];
    }
}

-(void)dealloc {
    [_outputStream close];
    CHRelease(_outputStream);
    CHRelease(_dataBuffer);
    CHRelease(_file);
    [super dealloc];
}

#pragma mark - Implementation
- (NSData *)defaultSecret{
    NSString *macAddress = [[UIDevice currentDevice] macaddress];
    NSString *constKey = [[[NSString alloc] initWithBytes:const_key length:strlen(const_key) encoding:NSUTF8StringEncoding] autorelease];
    CHKeychainItemWrapper *passcodeWrapper = [[[CHKeychainItemWrapper alloc] initWithIdentifier:kKeychainIdentifierPasscode account:nil] autorelease];
    NSString *passcode = [passcodeWrapper passcode];
    
    NSString *strSecret = [macAddress stringByAppendingString:constKey];
    if (passcode) {
        strSecret = [strSecret stringByAppendingString:passcode];
    }
    
    NSData *secretData = [strSecret sha256]; 
    return secretData;
}

- (void)cryptData:(NSData *)inData {
    if (inData) {
        size_t dataInLength = [inData length];
        //set default data out length to block size
        _dataOutLength = kCCBlockSizeAES128;
        
        size_t tmpDataOutLength = CCCryptorGetOutputLength(_cryptor, dataInLength, FALSE);
        if (tmpDataOutLength > 0) {
            _dataOutLength = tmpDataOutLength;
        }
        NSInteger startByte = 0; // Maintains the pointer for the input buffer
        
        char *dataIn = calloc(dataInLength, sizeof(char *));
        
        if (_dataOut != nil) {
            free(_dataOut);
        }
        _dataOut = calloc(_dataOutLength,sizeof(char *));
        
        // Get the chunk to be ciphered from the input buffer
        NSRange bytesRange = NSMakeRange((NSUInteger) startByte, (NSUInteger) dataInLength);
        [inData getBytes:dataIn range:bytesRange];
        
        CCCryptorStatus cryptStatus = CCCryptorUpdate(_cryptor, dataIn, dataInLength, _dataOut, _dataOutLength, &_dataOutMoved);
        
        if ( cryptStatus != kCCSuccess) {
            NSLog(@"Failed CCCryptorUpdate: %d", cryptStatus);
        }
        
        // Write the ciphered buffer into the output buffer
        bytesRange = NSMakeRange(_filePtr, (NSUInteger) _dataOutMoved);
        _totalLength += _dataOutMoved;
        _filePtr += _dataOutMoved;
        
        if (self.mode == CHCryptoModeInMemory) {
            [self.dataBuffer setLength:_totalLength];
            [self.dataBuffer replaceBytesInRange:bytesRange withBytes:_dataOut];
        } else {
            [self.outputStream write:(const uint8_t *)_dataOut maxLength:_dataOutMoved];
        }
        free(dataIn);
    }
}

- (BOOL)finalizeCipher {
    // Finalize encryption/decryption.
    self.status = CCCryptorFinal(_cryptor, _dataOut, _dataOutLength, &_dataOutMoved);
    _totalLength += _dataOutMoved;
    
    if (self.status != kCCSuccess) {
        [self log:Error format:@"Failed in cipher finalization with error:%d", self.status];
        CCCryptorRelease(_cryptor);
        free(_dataOut);
        return NO;
    }
    
    if (self.mode == CHCryptoModeInMemory) {
        // In the case of encryption, expand the buffer if it required some padding (an encrypted buffer will always be a multiple of 16).
        // In the case of decryption, truncate our buffer in case the encrypted buffer contained some padding
        [self.dataBuffer setLength:_totalLength];
        
        // Finalize the buffer with data from the CCCryptorFinal call
        NSRange bytesRange = NSMakeRange(_filePtr, (NSUInteger) _dataOutMoved);
        [self.dataBuffer replaceBytesInRange:bytesRange withBytes:_dataOut];
    } else {
        [self.outputStream write:(const uint8_t*)_dataOut maxLength:_dataOutMoved];
        [_outputStream close];
    }
    
    CCCryptorRelease(_cryptor);
    free(_dataOut);
    return YES;
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

@end

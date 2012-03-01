//
//  SFOAuthCrypto.m
//  SalesforceOAuth
//
//  Created by Amol Prabhu on 1/16/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "SFOAuthCrypto.h"

@interface SFOAuthCrypto()
@property (nonatomic, copy) NSMutableData *dataBuffer;
@property (nonatomic) CCCryptorStatus status;
- (void)doCipher:(NSData *)inData;
@end

@implementation SFOAuthCrypto 

@synthesize dataBuffer = _dataBuffer;
@synthesize status = _status;

#pragma mark - Object Lifecycle
- (id)initWithOperation:(CCOperation)operation key:(NSData *)key{
    if (self = [super init]) {
        char keyPtr[kCCKeySizeAES256 + 1];
        bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
        
        // Fetch key data
        [key getBytes:keyPtr length:sizeof(keyPtr)];
        
        CCCryptorStatus cryptStatus = CCCryptorCreate(operation, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                                      keyPtr, kCCKeySizeAES256,
                                                      NULL, 
                                                      &_cryptor);
        
        if (cryptStatus != kCCSuccess) {
            return nil;
        }
        _dataBuffer = [[NSMutableData alloc] init];
        _totalLength = 0; // Keeps track of the total length of the output buffer
        _filePtr = 0;   // Maintains the file pointer for the output buffer
        
    }
    return self;
}

-(void)dealloc {
    [_dataBuffer release];
    _dataBuffer = nil;
    
    [super dealloc];
}

#pragma mark - Implementation

- (void)doCipher:(NSData *)inData  {
    size_t dataInLength = [inData length];
    //set default data out length to block size
    _dataOutLength = kCCBlockSizeAES128;
    
    size_t tmpDataOutLength = CCCryptorGetOutputLength(_cryptor, dataInLength, FALSE);
    if (tmpDataOutLength > 0) {
        _dataOutLength = tmpDataOutLength;
    }
    NSInteger startByte = 0; // Maintains the pointer for the input buffer
    
    char *dataIn = malloc(dataInLength);
    
    if (_dataOut != nil) {
        free(_dataOut);
    }
    _dataOut = malloc(_dataOutLength);
    
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
    
    [self.dataBuffer setLength:_totalLength];
    [self.dataBuffer replaceBytesInRange:bytesRange withBytes:_dataOut];
    
    free(dataIn);
}

- (NSData *)finalizeCipher {
    // Finalize encryption/decryption.
    self.status = CCCryptorFinal(_cryptor, _dataOut, _dataOutLength, &_dataOutMoved);
    _totalLength += _dataOutMoved;
    
    if (self.status != kCCSuccess) {
        NSLog(@"Failed in cipher finalization with error:%d", self.status);
        CCCryptorRelease(_cryptor);
        free(_dataOut);
        return nil;
    }
    
    // In the case of encryption, expand the buffer if it required some padding (an encrypted buffer will always be a multiple of 16).
    // In the case of decryption, truncate our buffer in case the encrypted buffer contained some padding
    [self.dataBuffer setLength:_totalLength];
    
    // Finalize the buffer with data from the CCCryptorFinal call
    NSRange bytesRange = NSMakeRange(_filePtr, (NSUInteger) _dataOutMoved);
    [self.dataBuffer replaceBytesInRange:bytesRange withBytes:_dataOut];
    
    CCCryptorRelease(_cryptor);
    free(_dataOut);
    
    return [NSData dataWithData:self.dataBuffer];
}

- (void)encryptData:(NSData *)inData {
    if (inData) {
        [self doCipher:inData];
    }
}

- (NSData *)decryptData:(NSData *)data {
    NSData *decryptedData = nil;
    if (data) {
        [self doCipher:data];
        decryptedData = [self finalizeCipher];
    }
    return decryptedData;
}

@end

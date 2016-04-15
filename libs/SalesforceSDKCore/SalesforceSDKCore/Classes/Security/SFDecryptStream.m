//
//  SFDecryptStream.m
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import "SFDecryptStream.h"


@interface SFDecryptStream()

@property (nonatomic, strong) SFCryptChunks *cryptChunks;
@property (nonatomic, strong) NSInputStream *inStream;

@property (nonatomic, assign) uint8_t *remainders;
@property (nonatomic, assign) size_t remaindersLen;

@property (nonatomic, assign) uint8_t *readingBuffer;
@property (nonatomic, assign) size_t readingBufferLen;
@property (nonatomic, assign) size_t readingBufferFill;

@end


@implementation SFDecryptStream

#pragma mark - Lifecycle

- (instancetype)initWithData:(NSData *)data {
    self = [super initWithData:data];
    if (self) {
        _inStream = [[NSInputStream alloc] initWithData:data];
    }
    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)url {
    self = [super initWithURL:url];
    if (self) {
        _inStream = [[NSInputStream alloc] initWithURL:url];
    }
    return self;
}

- (nullable instancetype)initWithFileAtPath:(NSString *)path {
    _inStream = [[NSInputStream alloc] initWithFileAtPath:path];
    return self;
}


#pragma mark - Public Methods

- (void)setupWithKey:(NSData *)key andInitializationVector:(nullable NSData *)iv {
    NSAssert(!_cryptChunks, @"SFDecryptStream - setup is only allowed once.");
    if (!_cryptChunks) {
        _cryptChunks = [[SFCryptChunks alloc] initWithKey:key initializationVector:iv operation:kCCDecrypt];
        _cryptChunks.delegate = self;
    }
}


#pragma mark - Private

- (uint8_t *)remainders {
    if (!_remainders) {
        _remainders = malloc(sizeof(uint8_t) * SFCryptChunksCipherBlockSize);
    }
    return _remainders;
}

- (void)fillReadingBuffer:(uint8_t *)buffer bufferLen:(size_t)len {
    size_t fillLen = MIN(self.readingBufferLen - self.readingBufferFill, len);
    uint8_t *fillWindow = &(self.readingBuffer[self.readingBufferFill]);
    memcpy(fillWindow, buffer, fillLen);
    self.readingBufferFill += fillLen;
    
    // Left overs?
    self.remaindersLen = len - fillLen;
    if (self.remaindersLen > 0) {
        NSAssert(self.remaindersLen < SFCryptChunksCipherBlockSize, @"SFDecryptStream - there should never be more remainders than the size of the cipher block!");
        memcpy(self.remainders, &buffer[fillLen], self.remaindersLen);
    }
}


#pragma mark - SFCryptChunks Delegate

- (void)cryptChunk:(SFCryptChunks *)cryptChunks chunkResult:(uint8_t *)buffer bufferLen:(size_t)len {
    if (cryptChunks == self.cryptChunks) {
        [self fillReadingBuffer:buffer bufferLen:len];
    }
}


#pragma mark - NSInputStream

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    self.readingBuffer = buffer;
    self.readingBufferLen = len;
    self.readingBufferFill = 0;
    
    // Consume remainders first
    if (self.remaindersLen > 0) {
        [self fillReadingBuffer:self.remainders bufferLen:self.remaindersLen];
    }
    // Consume new bytes
    else {
        NSInteger bytesRead = [self.inStream read:buffer maxLength:len];
        if (bytesRead > 0) {
            [self.cryptChunks cryptBuffer:buffer bufferLen:bytesRead];
        }
        else if (bytesRead == 0) {
            [self.cryptChunks finalizeCrypt];
        }
        else {
            NSLog(@"SFDecryptStream - error on reading stream: %@.", self.streamError);
        }
    }
    
    return self.readingBufferFill;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
    return NO;
}

- (BOOL)hasBytesAvailable {
    return [self.inStream hasBytesAvailable] || ![self.cryptChunks cryptFinalized] || (self.remaindersLen > 0);
}

- (void)open {
    NSAssert(_cryptChunks, @"SFDecryptStream - you must setup first. Call -setupWithKey:andInitializationVector: before opening stream.");
    [self.inStream open];
}

- (void)close {
    [self.cryptChunks finalizeCrypt];
    [self.inStream close];
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
    self.inStream.delegate = delegate;
}

- (id<NSStreamDelegate>)delegate {
    return self.inStream.delegate;
}

- (id)propertyForKey:(NSString *)key {
    return [self.inStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
    return [self.inStream setProperty:property forKey:key];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [self.inStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [self.inStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (NSStreamStatus)streamStatus {
    NSStreamStatus status = self.inStream.streamStatus;
    // Reading stream is at end, but still have bytes to available?
    if (status == NSStreamStatusAtEnd && [self hasBytesAvailable]) {
        status = NSStreamStatusOpen;
    }
    return status;
}

- (NSError *)streamError {
    return self.inStream.streamError;
}

@end

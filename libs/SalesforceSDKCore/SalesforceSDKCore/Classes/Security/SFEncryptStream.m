//
//  SFEncryptStream.m
//  CryptoStream
//
//  Created by Joao Neves on 4/4/16.
//  Copyright © 2016 Salesforce. All rights reserved.
//

#import "SFEncryptStream.h"


@interface SFEncryptStream()

@property (nonatomic, strong) SFCryptChunks *cryptChunks;
@property (nonatomic, strong) NSOutputStream *outStream;

@end


@implementation SFEncryptStream

#pragma mark - Lifecycle

- (instancetype)initToMemory {
    self = [super initToMemory];
    if (self) {
        _outStream = [[NSOutputStream alloc] initToMemory];
    }
    return self;
}


- (instancetype)initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity {
    self = [super initToBuffer:buffer capacity:capacity];
    if (self) {
        _outStream = [[NSOutputStream alloc] initToBuffer:buffer capacity:capacity];
    }
    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)url append:(BOOL)shouldAppend {
    self = [super initWithURL:url append:shouldAppend];
    if (self) {
        _outStream = [[NSOutputStream alloc] initWithURL:url append:shouldAppend];
    }
    return self;
}

- (nullable instancetype)initToFileAtPath:(NSString *)path append:(BOOL)shouldAppend {
    _outStream = [[NSOutputStream alloc] initToFileAtPath:path append:shouldAppend];
    return self;
}


#pragma mark - Public Methods

- (void)setupWithKey:(NSData *)key andInitializationVector:(nullable NSData *)iv {
    NSAssert(!_cryptChunks, @"SFEncryptStream - setup is only allowed once.");
    if (!_cryptChunks) {
        _cryptChunks = [[SFCryptChunks alloc] initWithKey:key initializationVector:iv operation:kCCEncrypt];
        _cryptChunks.delegate = self;
    }
}


#pragma mark - SFCryptChunks Delegate

- (void)cryptChunk:(SFCryptChunks *)cryptChunks chunkResult:(uint8_t *)buffer bufferLen:(size_t)len {
    if (cryptChunks == self.cryptChunks) {
        [self.outStream write:buffer maxLength:len];
    }
}


#pragma mark - NSOutputStream

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    [self.cryptChunks cryptBuffer:buffer bufferLen:len];    
    // return full len, signalizing whole buffer was consumed.
    return len;
}

- (BOOL)hasSpaceAvailable {
    return [self.outStream hasSpaceAvailable];
}

- (void)open {
    NSAssert(_cryptChunks, @"SFEncryptStream - you must setup first. Call -setupWithKey:andInitializationVector: before opening stream.");
    [self.outStream open];
}

- (void)close {
    [self.cryptChunks finalizeCrypt];
    [self.outStream close];
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
    self.outStream.delegate = delegate;
}

- (id<NSStreamDelegate>)delegate {
    return self.outStream.delegate;
}

- (id)propertyForKey:(NSString *)key {
    return [self.outStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
    return [self.outStream setProperty:property forKey:key];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [self.outStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [self.outStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (NSStreamStatus)streamStatus {
    return self.outStream.streamStatus;
}

- (NSError *)streamError {
    return self.outStream.streamError;
}

@end

/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFEncryptStream.h"


@interface SFEncryptStream()

@property (nonatomic, strong) SFCryptChunks *cryptChunks;
@property (nonatomic, strong) NSOutputStream *outStream;

@end


@implementation SFEncryptStream

#pragma mark - Lifecycle

/**
 Pre iOS9 will crash if you call the designated initializers, so here we call just init on NSObject and be happy since we don't ever use functionality on super anyways and just want to wrapper an NSOutputStream
 */
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (instancetype)initToMemory {
    self = [super init];
    if (self) {
        _outStream = [[NSOutputStream alloc] initToMemory];
    }
    return self;
}

- (instancetype)initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity {
    self = [super init];
    if (self) {
        _outStream = [[NSOutputStream alloc] initToBuffer:buffer capacity:capacity];
    }
    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)url append:(BOOL)shouldAppend {
    self = [super init];
    if (self) {
        _outStream = [[NSOutputStream alloc] initWithURL:url append:shouldAppend];
    }
    return self;
}

- (nullable instancetype)initToFileAtPath:(NSString *)path append:(BOOL)shouldAppend {
    self = [super init];
    if (self){
        _outStream = [[NSOutputStream alloc] initToFileAtPath:path append:shouldAppend];
    }
    return self;
}


#pragma mark - Public Methods

- (void)setupWithKey:(NSData *)key andInitializationVector:(nullable NSData *)iv {
    NSAssert(!_cryptChunks, @"SFEncryptStream - setup is only allowed once.");
    if (!_cryptChunks) {
        _cryptChunks = [[SFCryptChunks alloc] initForEncryptionWithKey:key initializationVector:iv];
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

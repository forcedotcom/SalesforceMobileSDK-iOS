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

#import "CSFMultipartInputStream.h"
#import "CSFInputStreamElement.h"

static NSString * const kCSFInputStreamFooterFormat = @"--%@--\r\n";

@interface CSFMultipartInputStream ()

@property (nonatomic, strong) NSMutableArray *parts;
@property (nonatomic, strong, readwrite) NSString *boundary;
@property (nonatomic, strong) NSData *footer;
@property (nonatomic) NSUInteger currentPart;
@property (nonatomic) NSUInteger delivered;
@property (nonatomic, assign, readwrite) NSUInteger length;
@property (nonatomic, assign, readwrite) NSUInteger numberOfParts;
@property (nonatomic) NSStreamStatus status;

@end

@implementation CSFMultipartInputStream

- (id)init {
    self = [super init];
    if (self) {
        self.parts = [NSMutableArray new];
        self.boundary = [[NSProcessInfo processInfo] globallyUniqueString];

        NSString *footerString = [NSString stringWithFormat:kCSFInputStreamFooterFormat, self.boundary];
        self.footer = [footerString dataUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

- (void)updateLength {
    self.length = self.footer.length + [[self.parts valueForKeyPath:@"@sum.length"] unsignedIntegerValue];
}

- (void)addInputElement:(CSFInputStreamElement*)element {
    if (self.status == NSStreamStatusNotOpen) {
        [self.parts addObject:element];
        [self updateLength];
    }
    
    self.numberOfParts = self.parts.count;
}

#pragma mark Public methods

- (void)addObject:(id)object forKey:(NSString*)key {
    [self addInputElement:[[CSFInputStreamElement alloc] initWithObject:object boundary:self.boundary key:key]];
}

- (void)addObject:(id)object forKey:(NSString*)key withTransformer:(NSValueTransformer*)transformer {
    [self addInputElement:[[CSFInputStreamElement alloc] initWithObject:object boundary:self.boundary key:key transformer:transformer]];
}

- (void)addObject:(id)object forKey:(NSString*)key withMimeType:(NSString*)mimeType filename:(NSString*)filename {
    [self addInputElement:[[CSFInputStreamElement alloc] initWithObject:object boundary:self.boundary key:key mimeType:mimeType filename:filename]];
}

- (void)addObject:(id)object forKey:(NSString*)key withTransformer:(NSValueTransformer*)transformer mimeType:(NSString*)mimeType filename:(NSString*)filename {
    [self addInputElement:[[CSFInputStreamElement alloc] initWithObject:object boundary:self.boundary key:key transformer:transformer mimeType:mimeType filename:filename]];
}

- (void)addInputStream:(NSInputStream*)stream forKey:(NSString*)key withMimeType:(NSString*)mimeType filename:(NSString*)filename streamLength:(NSUInteger)length {
    [self addInputElement:[[CSFInputStreamElement alloc] initWithStream:stream boundary:self.boundary key:key mimeType:mimeType filename:filename streamLength:length]];
}

- (void)addFileAtPath:(NSString*)path forKey:(NSString*)key withMimeType:(NSString*)mimeType filename:(NSString*)filename {
    [self addInputElement:[[CSFInputStreamElement alloc] initWithObject:[NSURL fileURLWithPath:path] boundary:self.boundary key:key mimeType:mimeType filename:filename]];
}

#pragma mark Stream handling methods

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    NSUInteger sent = 0;
    NSUInteger read = 0;

    self.status = NSStreamStatusReading;
    while (self.delivered < self.length && sent < len && self.currentPart < self.parts.count) {
        if ((read = [[self.parts objectAtIndex:self.currentPart] read:(buffer + sent) maxLength:(len - sent)]) == 0) {
            self.currentPart++;
            continue;
        }

        sent += read;
        self.delivered += read;
    }

    if (self.delivered >= (self.length - self.footer.length) && sent < len) {
        read = MIN(self.footer.length - (self.delivered - (self.length - self.footer.length)), len - sent);
        [self.footer getBytes:buffer + sent range:NSMakeRange(self.delivered - (self.length - self.footer.length), read)];
        sent += read;
        self.delivered += read;
    }

    return sent;
}

- (BOOL)hasBytesAvailable {
    return (self.delivered < self.length);
}

- (void)open {
    self.status = NSStreamStatusOpen;
}

- (void)close {
    self.status = NSStreamStatusClosed;
}

- (NSStreamStatus)streamStatus {
    if (self.status != NSStreamStatusClosed && self.delivered >= self.length) {
        self.status = NSStreamStatusAtEnd;
    }

    return self.status;
}

#pragma mark Undocumented CFReadStream bridged methods

- (void)_scheduleInCFRunLoop:(NSRunLoop *)runLoop forMode:(id)mode {}
- (void)_setCFClientFlags:(CFOptionFlags)flags callback:(CFReadStreamClientCallBack)callback context:(CFStreamClientContext)context {}

@end

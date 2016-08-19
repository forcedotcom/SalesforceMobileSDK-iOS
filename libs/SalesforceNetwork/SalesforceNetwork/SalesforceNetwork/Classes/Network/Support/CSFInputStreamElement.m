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

#import "CSFInputStreamElement.h"
#import "CSFInternalDefines.h"
#import "NSValueTransformer+SalesforceNetwork.h"

static NSString * const kCSFInputStreamHeaderNameFormat = @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n";
static NSString * const kCSFInputStreamHeaderMimeFormat = @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\nContent-Type: %@\r\n\r\n";
static NSString * const kCSFInputStreamHeaderFullFormat = @"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n";

@interface CSFInputStreamElement ()

@property (nonatomic, strong, readwrite) id object;
@property (nonatomic, strong, readwrite) NSString *boundary;  // Note: This is strong so we don't unnecessarily duplicate this same string in memory
@property (nonatomic, copy, readwrite) NSString *key;
@property (nonatomic, copy, readwrite) NSString *mimeType;
@property (nonatomic, copy, readwrite) NSString *filename;
@property (nonatomic, assign, readwrite) NSUInteger headerLength;
@property (nonatomic, assign, readwrite) NSUInteger bodyLength;
@property (nonatomic, assign, readwrite) NSUInteger delivered;

@property (nonatomic, strong) NSValueTransformer *valueTransformer;
@property (nonatomic, strong) NSData *header;
@property (nonatomic, strong) NSInputStream *body;

@end

@implementation CSFInputStreamElement

#pragma mark Designated initializers

- (instancetype)init {
    self = [super init];
    return self;
}

- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key {
    self = [super init];
    if (self) {
        self.object = object;
        self.boundary = boundary;
        self.key = key;

        [self updateProperties];
    }
    return self;
}

- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key transformer:(NSValueTransformer*)transformer {
    self = [super init];
    if (self) {
        self.object = object;
        self.boundary = boundary;
        self.key = key;
        self.valueTransformer = transformer;

        [self updateProperties];
    }
    return self;
}

- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key mimeType:(NSString*)mimeType filename:(NSString*)filename {
    self = [super init];
    if (self) {
        self.object = object;
        self.boundary = boundary;
        self.key = key;
        self.mimeType = mimeType;
        self.filename = filename;

        [self updateProperties];
    }
    return self;
}

- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key transformer:(NSValueTransformer*)transformer mimeType:(NSString*)mimeType filename:(NSString*)filename {
    self = [super init];
    if (self) {
        self.object = object;
        self.boundary = boundary;
        self.key = key;
        self.valueTransformer = transformer;
        self.mimeType = mimeType;
        self.filename = filename;

        [self updateProperties];
    }
    return self;
}

- (instancetype)initWithStream:(NSInputStream*)stream boundary:(NSString*)boundary key:(NSString*)key mimeType:(NSString*)mimeType filename:(NSString*)filename streamLength:(NSUInteger)streamLength {
    self = [super init];
    if (self) {
        self.object = self.body = stream;
        self.boundary = boundary;
        self.key = key;
        self.mimeType = mimeType;
        self.filename = filename;
        self.bodyLength = streamLength;

        [self updateProperties];
    }
    return self;
}

#pragma mark - Setup

- (NSUInteger)length {
    return self.bodyLength + self.headerLength + 2;
}

- (void)updateProperties {
    // Determine if we need to implicitly create a value transformer for our input object
    if (!_valueTransformer) {
        _valueTransformer = [NSValueTransformer networkDataTransformerForObject:_object];
    }

    // If given a file wrapper, create an input stream for it
    // If we were given an NSData object directly, create a stream for it
    if ([_object isKindOfClass:[NSData class]]) {
        NSData *objectdata = (NSData*)_object;
        self.body = [NSInputStream inputStreamWithData:objectdata];
        self.bodyLength = objectdata.length;
    }

    else if ([_object isKindOfClass:[NSURL class]] && [(NSURL*)_object isFileURL]) {
        NSURL *fileUrl = (NSURL*)_object;
        
        if (!_filename) {
            _filename = fileUrl.lastPathComponent;
        }

        NSError *error = nil;
        NSFileManager *manager = [[NSFileManager alloc] init];
        NSDictionary *attributes = [manager attributesOfItemAtPath:fileUrl.path error:&error];

        if (error) {
            NetworkWarn(@"Unexpected error while reading filesystem attributes: %@", error);
        } else {
            self.body = [NSInputStream inputStreamWithURL:fileUrl];
            self.bodyLength = [attributes[NSFileSize] unsignedIntegerValue];
        }
    }

    // If we were given a value transformer, try and create output data for it
    else if (_valueTransformer) {
        id transformedValue = [_valueTransformer transformedValue:_object];
        if ([transformedValue isKindOfClass:[NSString class]]) {
            NSString *transformedString = (NSString*)transformedValue;
            transformedValue = [transformedString dataUsingEncoding:NSUTF8StringEncoding];
        }

        if ([transformedValue isKindOfClass:[NSData class]]) {
            NSData *transformedData = (NSData*)transformedValue;
            self.bodyLength = transformedData.length;
            self.body = [NSInputStream inputStreamWithData:transformedData];
        }
    }
    
    // Try to auto-detect the mime type based on our input filename, if provided
    if (!_mimeType && _filename) {
        self.mimeType = CSFMIMETypeForExtension(_filename.pathExtension);
    }
    
    // If we were given a boundary, try to deduce what the header will be in a multipart body
    if (_boundary) {
        NSString *headerString = nil;
        if (_key && _mimeType && _filename) {
            headerString = [NSString stringWithFormat:kCSFInputStreamHeaderFullFormat, _boundary, _key, _filename, _mimeType];
        } else if (_key && _mimeType) {
            headerString = [NSString stringWithFormat:kCSFInputStreamHeaderMimeFormat, _boundary, _key, _mimeType];
        } else if (_key) {
            headerString = [NSString stringWithFormat:kCSFInputStreamHeaderNameFormat, _boundary, _key];
        }
        if (headerString) {
            self.header = [headerString dataUsingEncoding:NSUTF8StringEncoding];
            self.headerLength = self.header.length;
        }
    }
}

#pragma mark Streaming

- (NSUInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    NSInteger sent = 0, read = 0;

    if (self.delivered >= self.length) {
        return 0;
    }

    if (self.delivered < self.headerLength && sent < len) {
        read = MIN(self.headerLength - self.delivered, len - sent);
        [self.header getBytes:buffer + sent range:NSMakeRange(self.delivered, read)];
        sent += read;
        self.delivered += sent;
    }

    if (self.body.streamStatus == NSStreamStatusNotOpen) {
        [self.body open];
    }
    
    if ([self.body hasBytesAvailable]) {
        while (self.delivered >= self.headerLength && self.delivered < (self.length - 2) && sent < len) {
            NSInteger streamLen = len - sent;
            read = [self.body read:buffer + sent maxLength:streamLen];
            if (read <= 0) {
                break;
            }
            
            sent += read;
            self.delivered += read;
        }
    }

    if (self.delivered >= (self.length - 2) && sent < len) {
        if (self.delivered == (self.length - 2)) {
            *(buffer + sent) = '\r';
            sent++;
            self.delivered++;
        }

        *(buffer + sent) = '\n';
        sent++;
        self.delivered++;
    }

    return sent;
}

@end

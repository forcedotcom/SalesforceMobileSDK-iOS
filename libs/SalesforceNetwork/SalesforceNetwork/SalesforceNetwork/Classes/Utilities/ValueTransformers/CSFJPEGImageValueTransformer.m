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

#import "CSFJPEGImageValueTransformer.h"
#import "CSFInternalDefines.h"

NSString * const CSFJPEGImageValueTransformerName = @"CSFJPEGImageValueTransformer";

@implementation CSFJPEGImageValueTransformer

+ (Class)transformedValueClass {
    return [NSData class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

#ifdef CSFPlatformiOS
- (id)transformedValue:(UIImage*)value {
    return ([value isKindOfClass:[UIImage class]]) ? UIImageJPEGRepresentation(value, 1.0) : nil;
}
#else
- (id)transformedValue:(NSImage*)value {
    NSData *result = nil;
    if ([value isKindOfClass:[NSImage class]]) {
        [value lockFocus];
        NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, value.size.width, value.size.height)];
        [value unlockFocus];
        result = [bitmapRep representationUsingType:NSJPEGFileType properties:Nil];
    }
    return result;
}
#endif

- (id)reverseTransformedValue:(NSData *)value {
    NSUIImage *result = nil;
    if ([value isKindOfClass:[NSData class]]) {
        result = [NSUIImage imageWithData:value];
    }
    return result;
}


@end

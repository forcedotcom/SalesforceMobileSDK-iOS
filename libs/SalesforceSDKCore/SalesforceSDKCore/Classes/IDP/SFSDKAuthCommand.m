/*
 SFSDKAuthCommand.m
 SalesforceSDKCore
 
 Created by Raj Rao on 9/28/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKAuthCommand+Internal.h"
#import "NSURL+SFAdditions.h"
#import "NSString+SFAdditions.h"
#import "SFSDKIDPConstants.h"
@interface SFSDKAuthCommand()
@property (strong, nonatomic) NSMutableDictionary *commandParameters;
@property (nonatomic, readwrite, nonnull) NSString *command;
@property (nonatomic, readwrite, nonnull) NSString *version;
@property (nonatomic, readwrite, nonnull) NSString *path;
@end

@implementation SFSDKAuthCommand

- (instancetype)init {
    self = [super init];
    if (self) {
        _commandParameters = [[NSMutableDictionary alloc] init];
        _version = kSFSpecVersion;
    }
    return self;
}

- (NSURL *)requestURL {
    
    NSAssert([self.scheme isEmptyOrWhitespaceAndNewlines]==false, @"Scheme cannot be nil");
    NSAssert([self.path isEmptyOrWhitespaceAndNewlines]==false, @"Path cannot be nil");
    NSAssert([self.version isEmptyOrWhitespaceAndNewlines]==false, @"Version cannot be nil");
    NSAssert([self.command isEmptyOrWhitespaceAndNewlines]==false, @"Command cannot be nil");
    
    NSString *urlPath = [NSString stringWithFormat:@"%@://%@/%@/%@",self.scheme,kSFSpecHost,self.version,self.command];
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:urlPath];
   
    NSMutableArray *items = [[NSMutableArray alloc] init];
    [self.commandParameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        obj = [[obj
                  stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
        [items addObject:[[NSURLQueryItem alloc] initWithName:key value:obj]];
    }];
    components.queryItems = items;
    return  components.URL;
    
}

- (void)fromRequestURL:(NSURL *)url {
    
    NSArray<NSString *> *pathComponents = [url pathComponents];
    NSAssert([pathComponents count] > 2, @"The path component of the url has to be of the form /v1.0/{COMMAND}");
    
    //e.g. Path should be of the form /v1.0/{COMMAND}
    self.version = pathComponents[1];
    self.command = pathComponents[2];
    
    self.scheme = [url scheme];
    
    //put all the query params in our backing store
    NSDictionary *dictionary = [url dictionaryFromQuery];
    [self.commandParameters addEntriesFromDictionary:dictionary];
    
}

- (BOOL)isAuthCommand:(NSURL *) url {
    return [url.pathComponents count] > 2 && [self.command.lowercaseString  isEqualToString:url.pathComponents[2].lowercaseString];
}

- (NSDictionary *)allParams {
    return [[NSDictionary alloc] initWithDictionary:self.commandParameters copyItems:YES];
}

- (void)setParamForKey:(NSString *)value key:(NSString *)key {
    
    if (key==nil || value==nil) return;
    
    [self.commandParameters setObject:value forKey:key];
}

- (NSString *)paramForKey:(NSString *)key {
    return [self.commandParameters objectForKey:key];
}

- (void)removeParam:(NSString *)key {
    return [self.commandParameters removeObjectForKey:key];
}


@end

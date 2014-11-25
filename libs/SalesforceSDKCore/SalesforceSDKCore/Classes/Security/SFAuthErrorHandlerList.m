/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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

#import "SFAuthErrorHandlerList.h"
#import "SFAuthErrorHandler.h"

@interface SFAuthErrorHandlerList ()

/**
 The mutable array/list of error hander objects.
 */
@property (nonatomic, strong) NSMutableArray *authHandlerMutableArray;

/**
 Retrieves an error handler, based on its name.
 @param name The name of the error handler to retrieve from the list.
 @return The error handler, or `nil` if no error handler with the given name was found.
 */
- (SFAuthErrorHandler *)retrieveAuthErrorHandlerWithName:(NSString *)name;

@end

@implementation SFAuthErrorHandlerList

@synthesize authHandlerMutableArray = _authHandlerMutableArray;

- (id)init
{
    self = [super init];
    if (self) {
        self.authHandlerMutableArray = [NSMutableArray array];
    }
    return self;
}

- (NSArray *)authHandlerArray
{
    return [self.authHandlerMutableArray copy];
}

- (void)addAuthErrorHandler:(SFAuthErrorHandler *)errorHandler
{
    [self addAuthErrorHandler:errorHandler atIndex:[self.authHandlerMutableArray count]];
}

- (void)addAuthErrorHandler:(SFAuthErrorHandler *)errorHandler atIndex:(NSUInteger)index
{
    SFAuthErrorHandler *existingHandler = [self retrieveAuthErrorHandlerWithName:errorHandler.name];
    if (existingHandler != nil) {
        [self log:SFLogLevelWarning format:@"Existing auth error handler with name '%@' will be removed.", existingHandler.name];
        [self removeAuthErrorHandler:existingHandler];
    }
    [self.authHandlerMutableArray insertObject:errorHandler atIndex:index];
}

- (void)removeAuthErrorHandlerWithName:(NSString *)errorHandlerName
{
    SFAuthErrorHandler *existingHandler = [self retrieveAuthErrorHandlerWithName:errorHandlerName];
    if (existingHandler == nil) {
        [self log:SFLogLevelWarning format:@"Auth error handler with name '%@' not found.  No action taken.", errorHandlerName];
    } else {
        [self removeAuthErrorHandler:existingHandler];
    }
}

- (void)removeAuthErrorHandler:(SFAuthErrorHandler *)errorHandler
{
    [self.authHandlerMutableArray removeObject:errorHandler];
}

- (BOOL)authErrorHandlerInList:(SFAuthErrorHandler *)errorHandler
{
    NSArray *resultArray = [self.authHandlerMutableArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"SELF == %@", errorHandler]];
    return ([resultArray count] > 0);
}

#pragma mark - Private methods

- (SFAuthErrorHandler *)retrieveAuthErrorHandlerWithName:(NSString *)name
{
    NSArray *resultArray = [self.authHandlerMutableArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"SELF.name MATCHES %@", name]];
    if ([resultArray count] > 0) {
        return resultArray[0];
    } else {
        return nil;
    }
}

@end

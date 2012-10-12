/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFVersionedArguments.h"

@interface SFVersionedArguments ()

@property (nonatomic,strong) SFJavaScriptPluginVersion* jsVersion; // not readonly in the .m
@property (nonatomic,strong) NSMutableArray* actualArguments; // not readonly in the .m

@end

@implementation SFVersionedArguments

@synthesize jsVersion = _jsVersion;
@synthesize actualArguments = _actualArguments;

-(id)initWithArguments:(NSMutableArray *)arguments
{
    self = [super init];
    if (self) {
        NSString* jsVersionStr;
        if ([arguments count] > 0) {
            NSObject* firstElt = [arguments objectAtIndex:0];
            if ([firstElt isKindOfClass:[NSDictionary class]]) {
                NSDictionary* firstDict = (NSDictionary*) firstElt;
                jsVersionStr = (NSString*) [firstDict objectForKey:@"version"];
            }
        }
        if (jsVersionStr) {
            NSMutableArray* shiftedArguments = [[NSMutableArray alloc] initWithCapacity:[arguments count] - 1];
            for(int i=1; i<[arguments count]; i++) {
                [shiftedArguments insertObject:[arguments objectAtIndex:i] atIndex:i-1];
            }
            self.actualArguments = shiftedArguments;
            self.jsVersion = [[SFJavaScriptPluginVersion alloc] initWithStr:jsVersionStr];
        }
        else {
            self.actualArguments = arguments;
            self.jsVersion = [[SFJavaScriptPluginVersion alloc] initWithStr:@""];
        }
    }
    
    return self;
}

@end

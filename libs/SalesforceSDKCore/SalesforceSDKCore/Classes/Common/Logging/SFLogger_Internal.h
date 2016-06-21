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

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <stdatomic.h>
#import "SFLogStorage.h"

extern NSString * SFLogNameForFlag(SFLogFlag flag);
extern NSString * SFLogNameForLogLevel(SFLogLevel level);

@interface DDLog () <SFLogStorage> @end

@interface SFLogIdentifier : NSObject

@property (nonatomic, weak) SFLogger *logger;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, assign) SFLogLevel logLevel;
@property (nonatomic, assign, readonly) SFLogFlag logFlag;
@property (nonatomic, assign) NSInteger context;

- (instancetype)initWithIdentifier:(NSString*)identifier NS_DESIGNATED_INITIALIZER;

@end

/////////////////

@interface SFLogTag : NSObject

@property (nonatomic, readonly) SEL selector;
@property (nonatomic, strong, readonly) Class originClass;

- (instancetype)initWithClass:(Class)originClass selector:(SEL)selector;

@end

/////////////////

@interface SFLogger () {
@public
    atomic_int_least32_t _contextCounter;
    NSMutableDictionary<NSString*,SFLogIdentifier*> *_logIdentifiers;
    NSMutableArray<SFLogIdentifier*> *_logIdentifiersByContext;
    NSObject<SFLogStorage> *_ddLog;
    DDFileLogger *_fileLogger;
    DDTTYLogger *_ttyLogger;
}

- (SFLogIdentifier*)logIdentifierForIdentifier:(NSString*)identifier;
- (SFLogIdentifier*)logIdentifierForContext:(NSInteger)context;
- (void)resetLoggers;

@end

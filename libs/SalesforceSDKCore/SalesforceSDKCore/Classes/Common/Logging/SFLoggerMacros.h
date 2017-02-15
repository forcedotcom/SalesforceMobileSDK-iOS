/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#ifndef SFLoggerMacros_h
#define SFLoggerMacros_h

#import <os/log.h>

typedef NS_ENUM(NSUInteger, SFLogFlag) {
    SFLogFlagError      = (1 << 0),
    SFLogFlagWarning    = (1 << 1),
    SFLogFlagInfo       = (1 << 2),
    SFLogFlagDebug      = (1 << 3),
    SFLogFlagVerbose    = (1 << 4),
    SFLogFlagNSLog      = (1 << 5)
};

typedef NS_ENUM(NSUInteger, SFLogLevel) {
    /**
     *  No logs
     */
    SFLogLevelOff       = 0,
    
    /**
     *  Error logs only
     */
    SFLogLevelError     = (SFLogFlagError),
    
    /**
     *  Error and warning logs
     */
    SFLogLevelWarning   = (SFLogLevelError   | SFLogFlagWarning),
    
    /**
     *  Error, warning and info logs
     */
    SFLogLevelInfo      = (SFLogLevelWarning | SFLogFlagInfo),
    
    /**
     *  Error, warning, info and debug logs
     */
    SFLogLevelDebug     = (SFLogLevelInfo    | SFLogFlagDebug),
    
    /**
     *  Error, warning, info, debug and verbose logs
     */
    SFLogLevelVerbose   = (SFLogLevelDebug   | SFLogFlagVerbose),
    
    /**
     *  All logs (1...11111)
     */
    SFLogLevelAll       = NSUIntegerMax
};

#define SF_LOG_MAX_IDENTIFIER_COUNT 100
extern SFLogLevel SFLoggerContextLogLevels[SF_LOG_MAX_IDENTIFIER_COUNT];
extern os_log_t SFLoggerOSLog(NSInteger context, NSString *category);
static NSUInteger SFLoggerDefaultContext = 1;
static BOOL SFLoggerLogToASL = YES;

#define SF_LOG_MACRO(async, lvl, flg, ctx, atag, fnct, msg) \
[SFLogger logAsync:async                                    \
             level:lvl                                      \
              flag:flg                                      \
           context:ctx                                      \
              file:__FILE__                                 \
          function:fnct                                     \
              line:__LINE__                                 \
               tag:atag                                     \
           message:msg]

#define _OS_LOG_SFLogFlagError      OS_LOG_TYPE_ERROR
#define _OS_LOG_SFLogFlagWarning    OS_LOG_TYPE_DEFAULT
#define _OS_LOG_SFLogFlagInfo       OS_LOG_TYPE_INFO
#define _OS_LOG_SFLogFlagDebug      OS_LOG_TYPE_DEBUG
#define _OS_LOG_SFLogFlagVerbose    OS_LOG_TYPE_DEBUG
#define _OS_LOG_SFLogFlagNSLog      OS_LOG_TYPE_DEFAULT

#define SF_LOG_TO_OS_LOG(flg) \
    _OS_LOG_##flg

#define SF_LOG_MAYBE(async, flg, ctx, tag, fnct, frmt, ...)                                                           \
    ({                                                                                                                \
        SFLogLevel level = SFLoggerContextLogLevels[MAX(1, ctx) - 1];                                                 \
        if (SFLoggerLogToASL || (flg & level)) {                                                                      \
            NSString *message = [NSString stringWithFormat:frmt, ##__VA_ARGS__];                                      \
            if (SFLoggerLogToASL) {                                                                                   \
                os_log_with_type(SFLoggerOSLog(MAX(1, ctx) - 1, tag), SF_LOG_TO_OS_LOG(flg), [message UTF8String]);   \
            }                                                                                                         \
            if (flg & level) {                                                                                        \
                SF_LOG_MACRO(async, level, flg, ctx, tag, fnct, message);                                             \
            }                                                                                                         \
        }                                                                                                             \
    })

#define SFLogErrorToContext(context, tag, frmt, ...)   SF_LOG_MAYBE(NO,  SFLogFlagError,   context, tag, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define SFLogWarnToContext(context, tag, frmt, ...)    SF_LOG_MAYBE(YES, SFLogFlagWarning, context, tag, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define SFLogInfoToContext(context, tag, frmt, ...)    SF_LOG_MAYBE(YES, SFLogFlagInfo,    context, tag, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define SFLogDebugToContext(context, tag, frmt, ...)   SF_LOG_MAYBE(YES, SFLogFlagDebug,   context, tag, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define SFLogVerboseToContext(context, tag, frmt, ...) SF_LOG_MAYBE(YES, SFLogFlagVerbose, context, tag, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define SFLogErrorToIdentifier(identifier, frmt, ...)     SFLogErrorToContext([SFLogger contextForIdentifier:identifier], nil, frmt, ##__VA_ARGS__)
#define SFLogWarnToIdentifier(identifier, frmt, ...)       SFLogWarnToContext([SFLogger contextForIdentifier:identifier], nil, frmt, ##__VA_ARGS__)
#define SFLogInfoToIdentifier(identifier, frmt, ...)       SFLogInfoToContext([SFLogger contextForIdentifier:identifier], nil, frmt, ##__VA_ARGS__)
#define SFLogDebugToIdentifier(identifier, frmt, ...)     SFLogDebugToContext([SFLogger contextForIdentifier:identifier], nil, frmt, ##__VA_ARGS__)
#define SFLogVerboseToIdentifier(identifier, frmt, ...) SFLogVerboseToContext([SFLogger contextForIdentifier:identifier], nil, frmt, ##__VA_ARGS__)

#define SFLogError(frmt, ...)      SFLogErrorToContext(SFLoggerDefaultContext, nil, frmt, ##__VA_ARGS__)
#define SFLogWarn(frmt, ...)        SFLogWarnToContext(SFLoggerDefaultContext, nil, frmt, ##__VA_ARGS__)
#define SFLogInfo(frmt, ...)        SFLogInfoToContext(SFLoggerDefaultContext, nil, frmt, ##__VA_ARGS__)
#define SFLogDebug(frmt, ...)      SFLogDebugToContext(SFLoggerDefaultContext, nil, frmt, ##__VA_ARGS__)
#define SFLogVerbose(frmt, ...)  SFLogVerboseToContext(SFLoggerDefaultContext, nil, frmt, ##__VA_ARGS__)

#define SFLogErrorTag(frmt, tag, ...)      SFLogErrorToContext(SFLoggerDefaultContext, tag, frmt, ##__VA_ARGS__)
#define SFLogWarnTag(frmt, tag, ...)        SFLogWarnToContext(SFLoggerDefaultContext, tag, frmt, ##__VA_ARGS__)
#define SFLogInfoTag(frmt, tag, ...)        SFLogInfoToContext(SFLoggerDefaultContext, tag, frmt, ##__VA_ARGS__)
#define SFLogDebugTag(frmt, tag, ...)      SFLogDebugToContext(SFLoggerDefaultContext, tag, frmt, ##__VA_ARGS__)
#define SFLogVerboseTag(frmt, tag, ...)  SFLogVerboseToContext(SFLoggerDefaultContext, tag, frmt, ##__VA_ARGS__)

#define SFLogCError(frmt, ...)    _Pragma ("GCC warning \"'SFLogCError' macro is deprecated, use SFLogError\"")     SFLogError(frmt, ##__VA_ARGS__)
#define SFLogCWarn(frmt, ...)     _Pragma ("GCC warning \"'SFLogCWarn' macro is deprecated, use SFLogWarn\"")       SFLogWarn(frmt, ##__VA_ARGS__)
#define SFLogCInfo(frmt, ...)     _Pragma ("GCC warning \"'SFLogCInfo' macro is deprecated, use SFLogInfo\"")       SFLogInfo(frmt, ##__VA_ARGS__)
#define SFLogCDebug(frmt, ...)    _Pragma ("GCC warning \"'SFLogCDebug' macro is deprecated, use SFLogDebug\"")     SFLogDebug(frmt, ##__VA_ARGS__)
#define SFLogCVerbose(frmt, ...)  _Pragma ("GCC warning \"'SFLogCVerbose' macro is deprecated, use SFLogVerbose\"") SFLogVerbose(frmt, ##__VA_ARGS__)

#endif /* SFLoggerMacros_h */

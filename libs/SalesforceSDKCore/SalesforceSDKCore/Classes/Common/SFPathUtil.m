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

#import "SFPathUtil.h"
#import "sys/xattr.h"
#import "SFFileProtectionHelper.h"

@implementation SFPathUtil

+ (void)addSkipBackupAttributeTo:(NSString *)filePath {
    //Apply flag to prevent from iCloud backup 
    u_int8_t b = 1;
    setxattr([filePath fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
}

+ (void)secureFileAtPath:(NSString *)filePath recursive:(BOOL)recursive fileProtection:(NSString *)fileProtection {
    //Apply flag to prevent from iCloud backup
    if (!filePath) {
        return;
    }
    
    [[self class] secureFilePath:filePath markAsNotBackup:YES fileProtection:fileProtection];
    
    if (recursive) {
        // doing additional logic of recursive is marked as true
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory]) {
            // If file path exists and isDirectory, apply skip back up flag to it's contents
            if (isDirectory) {
                NSArray *directoryContents = [fileManager contentsOfDirectoryAtPath:filePath error:nil];
                if (directoryContents) {
                    for (NSString *item in directoryContents) {
                        NSString *fileFullPath = [filePath stringByAppendingPathComponent:item];
                        [[self class] secureFileAtPath:fileFullPath recursive:recursive fileProtection:fileProtection ];
                    }
                }
            }
        }
    }
}

+ (void)createFileItemIfNotExist:(NSString *)path skipBackup:(BOOL)skipBackup {
    [self createFileItemIfNotExist:path skipBackup:skipBackup fileProtection:nil];
}

+ (void)createFileItemIfNotExist:(NSString *)path skipBackup:(BOOL)skipBackup fileProtection:(NSString *)fileProtection {
    if (!path) {
        return;
    }
    
    if (!fileProtection) {
        fileProtection = [SFFileProtectionHelper fileProtectionForPath:path];
    }
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:[NSDictionary dictionaryWithObjectsAndKeys:fileProtection, NSFileProtectionKey, nil] error:nil];
    }
    else {
        
        //update attributes
        [fileManager setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:fileProtection, NSFileProtectionKey, nil]
                                         ofItemAtPath:path error:nil];
    }
    
    if (skipBackup) {
        //Apply flag to prevent from iCloud backup
        [SFPathUtil addSkipBackupAttributeTo:path];
    }
}


+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder {
    return [[self class] absolutePathForDocumentFolder:folder fileProtection:nil];
}

+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder fileProtection:(NSString *)fileProtection {
    NSString *rootPath = [SFPathUtil applicationDocumentDirectory];
    NSString *path = [rootPath stringByAppendingPathComponent:folder];
    
    [self createFileItemIfNotExist:path skipBackup:YES fileProtection:fileProtection];
    return path;
}

+ (NSString *)absolutePathForCacheFolder:(NSString *)folder {
    return [[self class] absolutePathForCacheFolder:folder fileProtection:nil];
}

+ (NSString *)absolutePathForCacheFolder:(NSString *)folder fileProtection:(NSString *)fileProtection {
	NSString *rootPath = [SFPathUtil applicationCacheDirectory];
    NSString *path = [rootPath stringByAppendingPathComponent:folder];
    
    [self createFileItemIfNotExist:path skipBackup:YES fileProtection:fileProtection];
	return path;
}

+ (NSString *)absolutePathForLibraryFolder:(NSString *)folder {
    return [[self class] absolutePathForLibraryFolder:folder fileProtection:nil];
}

+ (NSString *)absolutePathForLibraryFolder:(NSString *)folder fileProtection:(NSString *)fileProtection {
    NSString *rootPath = [SFPathUtil applicationLibraryDirectory];
    NSString *path = [rootPath stringByAppendingPathComponent:folder];
    
    [self createFileItemIfNotExist:path skipBackup:YES fileProtection:fileProtection];
	return path;
}

+ (NSString *)applicationDocumentDirectory {
    NSString *path =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    return path;
}
                                    
+ (NSString *)applicationCacheDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
}

+ (NSString *)applicationLibraryDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
}

+ (void)secureFilePath:(NSString *)filePath markAsNotBackup:(BOOL)notbackupFlag {
    [[self class] secureFilePath:filePath markAsNotBackup:notbackupFlag fileProtection:nil];
}

+ (void)secureFilePath:(NSString *)filePath markAsNotBackup:(BOOL)notbackupFlag fileProtection:(NSString *)fileProtection {
    if (!fileProtection) {
        fileProtection = [SFFileProtectionHelper fileProtectionForPath:filePath];
    }
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:filePath]){
        NSError *error = nil;
        NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error:&error];
        if(nil != attrs && ![[attrs objectForKey:NSFileProtectionKey] isEqual:fileProtection]) {
            attrs = [NSDictionary dictionaryWithObject:fileProtection forKey:NSFileProtectionKey];
            [fileManager setAttributes:attrs ofItemAtPath:filePath error:&error];
        }
        
        if (notbackupFlag) {
            //Apply flag to prevent from iCloud backup 
            [SFPathUtil addSkipBackupAttributeTo:filePath];
        }
    }
}

@end

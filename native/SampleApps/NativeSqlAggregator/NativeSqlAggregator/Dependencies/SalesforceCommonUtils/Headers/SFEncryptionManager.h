//
//  SFEncryptionManager.h
//  SalesforceCommonUtils
//
//  Created by Qingqing Liu on 5/10/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SFEncryptionManagerFailedWithEmptyOutput 9001
#define SFEncryptionManagerFailedWithDecryption 9002

typedef void (^SFEncryptionCompletionBlock)(NSError *error);

/**This is a utility class that encrypts and decrypts file
 */
@interface SFEncryptionManager : NSObject {
}

/** Returns the singleton instance.
 */
+ (SFEncryptionManager *)sharedInstance;

/**Encrypt source file and save to target file
 
 @param sourceFile Path to file that needs to be encrypted
 @param targetFile Path to save the encrypted file
 @param completionBlock Call back block when encryption is done with NSObject as the single parameter.
 If successful, the NSError object returned will be nil.
 If failed, NSError will be populated with the error that caused encryption to fail
 */
- (void)encryptFile:(NSString *)sourceFile saveTo:(NSString *)targetFile completionBlock:(SFEncryptionCompletionBlock)completionBlock;

/**Descrypt source file and save to target file
 
 @param sourceFile Path to file that needs to be decrypted
 @param targetFile Path to save the decrypted file
 @param completionBlock Call back block when encryption is done with NSObject as the single parameter.
 If successful, the NSError object returned will be nil.
 If failed, NSError will be populated with the error that caused decryption to fail
 */
- (void)decryptFile:(NSString *)sourceFile saveTo:(NSString *)targetFile completionBlock:(SFEncryptionCompletionBlock)completionBlock;
@end

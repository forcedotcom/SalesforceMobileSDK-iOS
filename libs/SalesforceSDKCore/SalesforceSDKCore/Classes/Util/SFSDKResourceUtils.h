/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
NS_ASSUME_NONNULL_BEGIN

/** 
 * Class that handles access to Mobile SDK's main bundle.
 */
@interface SFSDKResourceUtils : NSObject

/**
 * @return Mobile SDK's main bundle.
 */
+ (NSBundle *)mainSdkBundle;

/**
 * Gets a localized string from the main Mobile SDK bundle.
 * @param localizationKey Localization key used to look up the localized string.
 * @return Localized string associated with the key.
 */
+ (NSString *)localizedString:(NSString *)localizationKey;

/**
 * Retrieves an image from the "Images" asset catalog of the Mobile SDK framework bundle.
 * @param name Name of the image in the asset catalog.
 * @return `UIImage` object containing the named image from the asset catalog.
*/
+ (UIImage *)imageNamed:(NSString*)name;

/**
 * Read a configuration resource file and parse its contents. The file must be in JSON format.
 * @param configFilePath Path to the configuration resource file.
 * @param error Input-output parameter that sets or returns any error that occurs during file reading.
 * @return `NSDictionary` object built from the file's contents.
 */
+ (nullable NSDictionary *)loadConfigFromFile:(NSString *)configFilePath error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END

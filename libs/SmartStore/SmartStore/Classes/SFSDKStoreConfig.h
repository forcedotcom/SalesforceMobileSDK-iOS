/*
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

#import <Foundation/Foundation.h>

@class SFSmartStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * Class encapsulating a SmartStore schema (soups).
 *
 * Config expected JSON in a resource file in JSON with the following:
 * {
 *     soups: [
 *          {
 *              soupName: xxx
 *              indexes: [
 *                  {
 *                      path: xxx
 *                      type: xxx
 *                  }
 *              ]
 *          }
 *     ]
 * }
 */
@interface SFSDKStoreConfig : NSObject

/**
 * Constructor
 * @param path to the config file
 * @return instance of SFSDKStoreConfig
 */
- (nullable id)initWithResourceAtPath:(NSString*)path;

/**
 * Register the soup from the config in the given store
 * NB: only feedback is through the logs - the config is static so getting it right is something the developer should do while writing the app
 *
 * @param store to register soups in.
 */
- (void) registerSoups:(SFSmartStore*) store;

/**
 * Check for soups in store
 * @return YES if soups are defined in config
 */
- (BOOL)hasSoups;

@end

NS_ASSUME_NONNULL_END

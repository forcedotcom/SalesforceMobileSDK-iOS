/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFForcePlugin.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * String used with Cordova to uniquely identify this plugin.
 */
extern NSString * const kSmartSyncPluginIdentifier;

@interface SFSmartSyncPlugin : SFForcePlugin

/**
 * Used for unit testing purposes only: allows the shared sync manager instance to be reset.
 */
- (void)resetSyncManager;

/**
 * Return details about a sync operation previously created. See [SFSmartSyncSyncManager:getSyncStatus].
 *
 * @param command Cordova arguments object containing "syncId".
 */
- (void)getSyncStatus:(CDVInvokedUrlCommand *)command;

/**
 * Starts a sync up operation. See [SFSmartSyncSyncManager syncUp].
 *
 * @param command Cordova arguments object containing "soupName" and "options".
 */
- (void)syncUp:(CDVInvokedUrlCommand *)command;

/**
 * Starts a sync down operation. See [SFSmartSyncSyncManager syncDown].
 *
 * @param command Cordova arguments object containing "soupName", "target" and "options".
 */
- (void)syncDown:(CDVInvokedUrlCommand *)command;

/**
 * Starts a re-sync operation. See [SFSmartSyncSyncManager reSync].
 *
 * @param command Cordova arguments object containing "syncId".
 */
- (void)reSync:(CDVInvokedUrlCommand *)command;

/**
 * Starts a ghost record clean operation. See [SFSmartSyncSyncManager cleanResyncGhosts].
 *
 * @param command Cordova arguments object containing "syncId".
 */
- (void) cleanResyncGhosts:(CDVInvokedUrlCommand *)command;

@end

NS_ASSUME_NONNULL_END

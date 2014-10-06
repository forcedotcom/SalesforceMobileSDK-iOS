/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSyncPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import <SalesforceCommonUtils/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SmartSync/SFSmartSyncSyncManager.h>

//NOTE: must match value in Cordova's config.xml file
NSString * const kSmartSyncPluginIdentifier = @"com.salesforce.smartsync";

// Private constants
NSString * const kSyncSoupNameArg = @"soupName";
NSString * const kSyncTargetArg = @"target";
NSString * const kSyncOptionsArg = @"options";
NSString * const kSyncIdArg = @"syncId";
NSString * const kSyncEventType = @"sync";
NSString * const kSyncDetail = @"detail";


@interface SFSmartSyncPlugin ()

@property (nonatomic, strong) SFSmartSyncSyncManager *syncManager;

@end

@implementation SFSmartSyncPlugin

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView 
{
    self = [super initWithWebView:theWebView];
    
    if (nil != self)  {
        SFUserAccount* user = [SFUserAccountManager sharedInstance].currentUser;
        self.syncManager = [SFSmartSyncSyncManager sharedInstance:user];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSyncNotification:) name:kSyncManagerNotification object:nil];
    }
    return self;
}

- (void) dealloc
{
}

- (void)handleSyncNotification:(NSNotification*)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *syncData = [NSJSONSerialization dataWithJSONObject:notification.object
                                                       options:0 // non-pretty printing
                                                         error:&error];
        if(error) {
            [self log:SFLogLevelError format:@"JSON Parsing Error: %@", error];
        }
        else {
            NSString* syncAsString = [[NSString alloc] initWithData:syncData encoding:NSUTF8StringEncoding];
            NSString* js = [
                            @[@"document.dispatchEvent(new CustomEvent(\"",
                              kSyncEventType,
                              @"\", { \"",
                              kSyncDetail,
                              @"\": ",
                              syncAsString,
                              @"}))" ]
                            componentsJoinedByString:@""
                            ];
            [self writeJavascript:js];
        }
    });
}

#pragma mark - Smart sync plugin methods

- (void) getSyncStatus:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSNumber* syncId = (NSNumber*) [argsDict nonNullObjectForKey:kSyncIdArg];
        
        [self log:SFLogLevelDebug format:@"getSyncStatus with sync id: %@", syncId];
        
        NSDictionary* sync = [self.syncManager getSyncStatus:syncId];
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sync];
    } command:command];
}

- (void) syncDown:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSyncSoupNameArg];
        NSDictionary *target = [argsDict nonNullObjectForKey:kSyncTargetArg];
        NSDictionary *options = [argsDict nonNullObjectForKey:kSyncOptionsArg];
        
        // Record sync
        NSDictionary* sync = [self.syncManager recordSync:kSyncManagerSyncTypeDown withTarget:target withSoupName:soupName withOptions:options];
        
        NSNumber* syncId = sync[kSyncManagerSyncId];
        
        [self log:SFLogLevelDebug format:@"syncDown # %@ from soup: %@", syncId, soupName];
        
        // Run sync (async)
        [self.syncManager runSync:syncId];
        
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sync];
    } command:command];
}

- (void) syncUp:(CDVInvokedUrlCommand *)command
{
    [self runCommand:^(NSDictionary* argsDict) {
        NSString *soupName = [argsDict nonNullObjectForKey:kSyncSoupNameArg];
        NSDictionary *options = [argsDict nonNullObjectForKey:kSyncOptionsArg];
        
        // Record sync
        NSDictionary* sync = [self.syncManager recordSync:kSyncManagerSyncTypeUp withTarget:nil withSoupName:soupName withOptions:options];
        
        NSNumber* syncId = sync[kSyncManagerSyncId];

        [self log:SFLogLevelDebug format:@"syncUp # %@ from soup: %@", syncId, soupName];
        
        // Run sync (async)
        [self.syncManager runSync:syncId];
        
        return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sync];
    } command:command];
}

@end

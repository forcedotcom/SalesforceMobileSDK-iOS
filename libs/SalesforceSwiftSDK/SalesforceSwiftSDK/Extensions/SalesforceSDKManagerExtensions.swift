/*
 SalesforceSDKManagerExtensions
 Created by Raj Rao on 11/27/17.
 
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
import Foundation
import SalesforceSDKCore
import SmartSync
import PromiseKit

extension SalesforceSwiftSDKManager {
    
    /// instance of SalesforceSDKManagerBuilder
    public static var Builder:SalesforceSDKManagerBuilder.Type {
        get {
           _ = SalesforceSwiftSDKManager.initSDK()
           return SalesforceSDKManagerBuilder.self
        }
    }
   
    /// SalesforceSDKManagerBuilder class.
    public class SalesforceSDKManagerBuilder {
        
        /**
         Provides a Builder based mechanism to setup the app config for the Salesforce Application.
         ```
         SalesforceSwiftSDKManager.Builder.configure { (appconfig) in
             appconfig.remoteAccessConsumerKey = RemoteAccessConsumerKey
             appconfig.oauthRedirectURI = OAuthRedirectURI
             appconfig.oauthScopes = ["web", "api"]
         }
         ```
         - Parameter config: The block which will be invoked with a config object.
         - Returns: The instance of SalesforceSDKManagerBuilder.
         */
        public class func configure(config : @escaping (SFSDKAppConfig) -> Void ) -> SalesforceSDKManagerBuilder.Type {
            config(SalesforceSwiftSDKManager.shared().appConfig!)
            return self
        }
        
        /**
         Provides a Builder based mechanism to setup the post inititialization settings for the Salesforce Application.
         ```
         SalesforceSwiftSDKManager.Builder.configure { (appconfig) in
         appconfig.remoteAccessConsumerKey = RemoteAccessConsumerKey
         appconfig.oauthRedirectURI = OAuthRedirectURI
         appconfig.oauthScopes = ["web", "api"]
         }.postInit {
         
         }
         ```
         - Parameter action: The block which will be invoked.
         - Returns: The instance of SalesforceSDKManagerBuilder.
         */
        public class func postInit(action: () -> Void) -> SalesforceSDKManagerBuilder.Type {
            action()
            return self
        }

        /**
         Provides a way to set the post launch action for the Salesforce Application.
         ```
         SalesforceSwiftSDKManager.Builder.configure { (appconfig) in
             appconfig.remoteAccessConsumerKey = RemoteAccessConsumerKey
             appconfig.oauthRedirectURI = OAuthRedirectURI
             appconfig.oauthScopes = ["web", "api"]
         }
         .postLaunch { (launchActionList: SFSDKLaunchAction) in
             //Some post launch code.
         }.done()
         ```
         - Parameter action: The block which will be invoked after a succesfull SDK Launch.
         - Returns: The instance of SalesforceSDKManagerBuilder.
         */
         public class func postLaunch(action : @escaping SFSDKPostLaunchCallbackBlock) -> SalesforceSDKManagerBuilder.Type {
            SalesforceSwiftSDKManager.shared().postLaunchAction = action
            return self
         }

        /**
         Provides a way to set the post logout action for the Salesforce Application.
         ```
         SalesforceSwiftSDKManager.Builder.configure { (appconfig) in
             appconfig.remoteAccessConsumerKey = RemoteAccessConsumerKey
             appconfig.oauthRedirectURI = OAuthRedirectURI
             appconfig.oauthScopes = ["web", "api"]
         }
         .postLaunch {  (launchActionList: SFSDKLaunchAction) in
            ...
         }
         .postLogout {
             
         }.done()
         ```
         - Parameter action: The block which will be invoked after a succesfull SDK Launch.
         - Returns: The instance of SalesforceSDKManagerBuilder.
         */
        public class func postLogout(action : @escaping SFSDKLogoutCallbackBlock) -> SalesforceSDKManagerBuilder.Type {
            SalesforceSwiftSDKManager.shared().postLogoutAction = action
            return self
        }

        /**
         Provides a way to set the switch user action for the Salesforce Application.
         ```
         SalesforceSwiftSDKManager.Builder.configure { (appconfig) in
         appconfig.remoteAccessConsumerKey = RemoteAccessConsumerKey
         appconfig.oauthRedirectURI = OAuthRedirectURI
         appconfig.oauthScopes = ["web", "api"]
         }
         .postLaunch {  (launchActionList: SFSDKLaunchAction) in
         ...
         }
         .postLogout {
         
         }
         .switchUser { from,to in
         
         }.done()
         ```
         - Parameter action: The block which will be invoked after a succesfull SDK Launch.
         - Returns: The instance of SalesforceSDKManagerBuilder.
         */
        public class func switchUser(action : @escaping SFSDKSwitchUserCallbackBlock) -> SalesforceSDKManagerBuilder.Type {
            SalesforceSwiftSDKManager.shared().switchUserAction = action
            return self
        }

        /**
         Provides a way to set the error handling during sdk launch for the Salesforce Application.
         ```
         SalesforceSwiftSDKManager.Builder.configure { (appconfig) in
             appconfig.remoteAccessConsumerKey = RemoteAccessConsumerKey
             appconfig.oauthRedirectURI = OAuthRedirectURI
             appconfig.oauthScopes = ["web", "api"]
         }
         .postLaunch {  (launchActionList: SFSDKLaunchAction) in
         ...
         }
         .postLogout {
         
         }
         .switchUser { from,to in
         
         }
         .launchError { error,launchAction in
         
         }.done()
         ```
         - Parameter action: The block which will be invoked after a succesfull SDK Launch.
         - Returns: The instance of SalesforceSDKManagerBuilder.
         */
        public class func launchError(action : @escaping SFSDKLaunchErrorCallbackBlock) -> SalesforceSDKManagerBuilder.Type {
            SalesforceSwiftSDKManager.shared().launchErrorAction = action
            SalesforceSwiftLogger.sharedInstance().e(SalesforceSwiftSDKManager.self, message: "Error occured during launch")
            return self
        }
        
        /**
         Last call for the builder returns Void to suppress warnings.
        */
        public class func done () -> Void {
            
        }
    }
}



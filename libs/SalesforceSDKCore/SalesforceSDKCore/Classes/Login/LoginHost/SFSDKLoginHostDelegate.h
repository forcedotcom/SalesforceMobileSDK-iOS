/*
 SFSDKLoginHostDelegate.h
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.

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

@class SFSDKLoginHostListViewController;

/**
 * Use the SFSDKLoginHostDelegate to be notified of the actions taken by the user on the login host list view controller.
 */
@protocol SFSDKLoginHostDelegate <NSObject>

@optional

/**
 * Notifies the delegate that a new login host viewcontroller will be presented.
 * @param hostListViewController The instance sending this message.
 * @param loginHostViewController The view controller that will be presented.
 */
- (void)hostListViewController:(SFSDKLoginHostListViewController *)hostListViewController willPresentLoginHostViewController:(UIViewController *)loginHostViewController;

/**
 * Notifies the delegate that a login host has been selected by the user.
 * This will be a good time to dismiss the host list view controller.
 * @param hostListViewController The instance sending this message.
 */
- (void)hostListViewControllerDidSelectLoginHost:(SFSDKLoginHostListViewController *)hostListViewController;

/**
 * Notifies the delegate that a login host has been added to the list of hosts.
 * @param hostListViewController The instance sending this message.
 */
- (void)hostListViewControllerDidAddLoginHost:(SFSDKLoginHostListViewController *)hostListViewController;

/**
 * Notifies the delegate that user cancels out from the login host picking flow
 * @param hostListViewController The instance sending this message.
 */
- (void)hostListViewControllerDidCancelLoginHost:(SFSDKLoginHostListViewController *)hostListViewController;


@end
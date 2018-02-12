/*
 SFLoginExtendedViewController.m
 
 Created by Raj Rao on 02/09/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFLoginExtendedViewController.h"

@interface SFLoginExtendedViewController ()

@end

@implementation SFLoginExtendedViewController

- (UIBarButtonItem *)createBackButton {
    // setup left bar button
    UIImage *image = [[SFSDKResourceUtils imageNamed:@"globalheader-back-arrow"]  imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:nil];
}

- (UIBarButtonItem *)createSettingsButton {
    UIImage *image = [[SFSDKResourceUtils imageNamed:@"login-window-gear"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:nil];
}

- (UINavigationItem *)createTitleItem {
    NSString *title = [SFSDKResourceUtils localizedString:@"SmartSyncLogin"];
    // Setup top item.
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:title];
    return item;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showHostListView {
    return [super showHostListView];
}

- (void)hideHostListView:(BOOL)animated {
    return [super hideHostListView:animated];
}

- (void)handleBackButtonAction {
    [super handleBackButtonAction];
}

- (BOOL)shouldShowBackButton {
    return [super shouldShowBackButton];
}

- (void)handleLoginHostSelectedAction:(SFSDKLoginHost *)loginHost {
    return [super handleLoginHostSelectedAction:loginHost];
}
@end

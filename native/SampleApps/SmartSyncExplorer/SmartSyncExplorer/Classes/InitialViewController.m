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

#import "InitialViewController.h"

@implementation InitialViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.appLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    if (!self.appLabel.text) {
        self.appLabel.text = [self buildAppLabel];
        self.appLabel.font = [UIFont systemFontOfSize:20.0];
    }
    [self.view addSubview:self.appLabel];
}

- (void)viewWillLayoutSubviews
{
    CGSize appLabelTextSize = [self.appLabel.text sizeWithAttributes:@{ NSFontAttributeName:self.appLabel.font }];
    CGFloat w = appLabelTextSize.width;
    CGFloat h = appLabelTextSize.height;
    CGFloat x = CGRectGetMidX(self.view.frame) - (w / 2.0);
    CGFloat y = CGRectGetMidY(self.view.frame) - (h / 2.0);
    self.appLabel.frame = CGRectMake(x, y, w, h);
}

#pragma mark - Private methods

- (NSString *)buildAppLabel
{
    NSDictionary *bundleInfoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appLabel = [NSString stringWithFormat:@"%@ Sample App", bundleInfoDict[@"CFBundleDisplayName"]];
    return appLabel;
}

@end

/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFAlertView.h"

@interface SFAlertView ()

@property (nonatomic, strong, nullable, readwrite) UIAlertView *alertView;

@end

@implementation SFAlertView

- (nullable instancetype)initWithTitle:(nullable NSString *)title
                               message:(nullable NSString *)message
                              delegate:(nullable id /*<UIAlertViewDelegate>*/)delegate
                     cancelButtonTitle:(nullable NSString *)cancelButtonTitle
                     otherButtonTitles:(nullable NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION {
    
    self.alertView = [[UIAlertView alloc] init];
    self.alertView.title = title;
    self.alertView.message = message;
    self.alertView.delegate = delegate;
    
    if (cancelButtonTitle) {
        [self.alertView addButtonWithTitle:cancelButtonTitle];
        self.alertView.cancelButtonIndex = 0;
    }
    
    va_list args;
    va_start(args, otherButtonTitles);
    for (NSString *arg = otherButtonTitles; arg != nil; arg = va_arg(args, NSString*)) {
        [self.alertView addButtonWithTitle:arg];
    }
    va_end(args);

    return self;
}

- (void)setTag:(NSInteger)tag {
    self.alertView.tag = tag;
}

- (NSInteger)tag {
    return self.alertView.tag;
}

- (void)setDelegate:(id<UIAlertViewDelegate>)delegate {
    self.alertView.delegate = delegate;
}

- (id<UIAlertViewDelegate>)delegate {
    return self.alertView.delegate;
}

- (void)show {
    [self.alertView show];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
    [self.alertView dismissWithClickedButtonIndex:buttonIndex animated:animated];
}

@end

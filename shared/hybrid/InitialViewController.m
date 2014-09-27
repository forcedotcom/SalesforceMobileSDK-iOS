//
//  InitialViewController.m
//  VFConnector
//
//  Created by Kevin Hawkins on 9/26/14.
//
//

#import "InitialViewController.h"

static NSString * const kDefaultHybridAppLabel = @"SDK Hybrid App";

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
        self.appLabel.text = kDefaultHybridAppLabel;
        self.appLabel.font = [UIFont systemFontOfSize:25.0];
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

@end

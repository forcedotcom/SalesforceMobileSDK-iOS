/*
 SFSDKUITableViewCell.m
 SalesforceSDKCore
 
 Created by Raj Rao on 6/05/18.
 
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
#import "SFSDKUITableViewCell.h"
#import "SFSDKUserSelectionTableViewController.h"
#import "UIColor+SFSDKIDP.m"
#import "UIFont+SFSDKIDP.h"
#import "SFSDKResourceUtils.h"
static CGFloat kHorizontalSpace = 12;
static CGFloat kImageWidth = 60;
static CGFloat kImageHeight = 60;

@interface SFSDKUITableViewCell()
@property (strong,nonatomic) UILabel *titleLabel;
@property (strong,nonatomic) UILabel *detailLabel;
@property (strong,nonatomic) UIImageView *profileImageView;
@end

@implementation SFSDKUITableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    self.contentView.backgroundColor = [UIColor tableCellBackgroundColor];
    UIImage *pimage = [SFSDKResourceUtils imageNamed:@"profile-placeholder"];
    UIImage *image = [SFSDKUITableViewCell resizeImage:pimage  size:CGSizeMake(kImageWidth, kImageHeight)];
    
    self.layer.borderWidth = kHorizontalSpace/2;
    self.layer.borderColor = [UIColor backgroundcolor].CGColor;
    self.profileImageView = [[UIImageView alloc] initWithImage:image];
    self.profileImageView.backgroundColor = [UIColor grayColor];
    [self.profileImageView setBounds:CGRectMake(0, 0, kImageWidth, kImageHeight)];
    self.profileImageView.image = image;
    self.profileImageView.layer.cornerRadius = self.profileImageView.frame.size.width / 2;
    self.profileImageView.layer.masksToBounds = YES;
    
    self.profileImageView.clipsToBounds = YES;
    self.titleLabel = [[UILabel alloc] init];
    self.detailLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont textRegular:16.0];
    self.titleLabel.textColor = [UIColor defaultTextColor];
    self.detailLabel.font = [UIFont textRegular:14.0];;
    self.detailLabel.textColor = [UIColor weakTextColor];
    self.profileImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addSubview:self.profileImageView];
    [self.contentView addSubview:self.titleLabel];
    [self.contentView addSubview:self.detailLabel];
    
    [self.profileImageView.leftAnchor constraintEqualToAnchor:self.contentView.leftAnchor constant:12].active = YES;

    [self.profileImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor].active = YES;

    [self.titleLabel.leftAnchor constraintEqualToAnchor:self.profileImageView.rightAnchor constant:12].active = YES;

   [self.titleLabel.lastBaselineAnchor  constraintEqualToAnchor:self.contentView.centerYAnchor constant:-3].active = YES;

    [self.detailLabel.topAnchor  constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4].active = YES;
    
   [self.detailLabel.leftAnchor  constraintEqualToAnchor:self.profileImageView.rightAnchor constant:12].active = YES;
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setHostName:(NSString *)hostName {
    self.detailLabel.text = hostName;
}

- (void)setUserName:(NSString *)userName {
    self.titleLabel.text = userName;
}

- (void)setProfileImage:(UIImage *)profileImage {
    UIImage *image = [SFSDKUITableViewCell resizeImage:profileImage  size:CGSizeMake(kImageWidth, kImageHeight)];
    self.profileImageView.image = image;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

+ (NSString *)reuseCellIdentifier {
    return @"sfsdkusercellview";
}

+ (CGFloat)cellHeight {
    return 123;
}

+ (UIImage *)resizeImage:(UIImage *)image size:(CGSize)size{
    CGRect rect = CGRectMake(0.0,0.0,size.width,size.height);
    UIGraphicsBeginImageContext(rect.size);
    [image drawInRect:rect];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end

//
//  SFCollectionView.h
//  SalesforceCommonUtils
//
//  Created by João Neves on 4/3/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SFCollectionView;

@protocol SFCollectionViewDelegate <NSObject>

@optional
- (void)collectionViewReloadFinished:(SFCollectionView*)collectionView;

@end

@interface SFCollectionView : UICollectionView

@property (nonatomic, weak) id<SFCollectionViewDelegate> sfDelegate;
@property (nonatomic, readonly) NSUInteger numberOfItemsTotal;
@property (nonatomic, readonly, getter=isReloading) BOOL reloading;

@end

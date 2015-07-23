//
//  CSFNetwork+SalesforcePrivate.h
//  SalesforceNetwork
//
//  Created by Michael Nachbaur on 7/23/15.
//  Copyright (c) 2015 salesforce.com. All rights reserved.
//

#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "CSFNetwork+Internal.h"

@interface CSFNetwork (SalesforcePrivate) <SFUserAccountManagerDelegate>

- (void)setupSalesforceObserver;

@end

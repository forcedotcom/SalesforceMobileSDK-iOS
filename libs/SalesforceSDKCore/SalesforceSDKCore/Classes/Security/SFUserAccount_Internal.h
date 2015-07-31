//
//  SFUserAccount_Internal.h
//  SalesforceSDKCore
//
//  Created by Michael Nachbaur on 7/31/15.
//  Copyright (c) 2015 salesforce.com. All rights reserved.
//

#import "SFUserAccount.h"

@interface SFUserAccount ()

@property (nonatomic, readwrite, getter = isUserDeleted) BOOL userDeleted;

@end

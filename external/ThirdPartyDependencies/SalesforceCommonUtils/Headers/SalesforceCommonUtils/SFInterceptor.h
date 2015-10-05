//
//  SFInterceptor.h
//  SalesforceCommonUtils
//
//  Created by João Neves on 4/28/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SFInterceptorDelegate <NSObject>

@required
// Called after the invocation is invoked
- (void)interceped:(NSInvocation*)invocation;

@end

@interface SFInterceptor : NSProxy

@property (nonatomic, weak) id<SFInterceptorDelegate> delegate;
@property (nonatomic, weak, readonly) id target;
@property (nonatomic, strong, readonly) NSSet* selectorsToIntercept;

+ (instancetype)new:(id<SFInterceptorDelegate>)delegate target:(id)target intercepts:(SEL)sel1, ... NS_REQUIRES_NIL_TERMINATION;

@end

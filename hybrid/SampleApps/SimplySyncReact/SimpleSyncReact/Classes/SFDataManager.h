// Copyright 2004-present Facebook. All Rights Reserved.

#import <Foundation/Foundation.h>

#import <ReactKit/RCTBridgeModule.h>
#import <JavaScriptCore/JavaScriptCore.h>


@protocol SFDataManagerJSExports <JSExport>

+ (NSString *)getFullName;

@end

@interface SFDataManager : UIViewController <RCTBridgeModule,SFDataManagerJSExports>



@end


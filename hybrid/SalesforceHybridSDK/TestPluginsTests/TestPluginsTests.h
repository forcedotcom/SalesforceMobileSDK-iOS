//
//  TestPluginsTests.h
//  TestPluginsTests
//
//  Created by Todd Stellanova on 1/13/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class SFTestRunnerPlugin;

@interface TestPluginsTests : SenTestCase {
    NSString *_jsTestName;
    SFTestRunnerPlugin *_testRunnerPlugin;
}

@property (nonatomic, strong) NSString *jsTestName;

@end

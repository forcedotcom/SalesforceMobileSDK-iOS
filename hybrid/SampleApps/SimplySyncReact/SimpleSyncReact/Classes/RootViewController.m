#import "RootViewController.h"
#import <ReactKit/RCTRootView.h>
#include "TargetConditionals.h"


@implementation RootViewController

#pragma mark Misc

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{

}


#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSURL *jsCodeLocation;
    RCTRootView *rootView = [[RCTRootView alloc] init];
    
    #if (TARGET_IPHONE_SIMULATOR)
      jsCodeLocation = [NSURL URLWithString:@"http://localhost:8081/SimpleSyncReact/js/App.includeRequire.runModule.bundle"];
    #else
        jsCodeLocation = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
    #endif
    
    rootView.scriptURL = jsCodeLocation;
    rootView.moduleName = @"App";
    
    self.view = rootView;
    
 }


@end

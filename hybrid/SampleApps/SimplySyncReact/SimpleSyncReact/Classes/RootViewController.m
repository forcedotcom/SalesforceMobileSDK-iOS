#import "RootViewController.h"
#import <React/RCTRootView.h>
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
    
    #if (TARGET_IPHONE_SIMULATOR)
      jsCodeLocation = [NSURL URLWithString:@"http://localhost:8081/SimpleSyncReact/js/App.includeRequire.runModule.bundle"];
    #else
      jsCodeLocation = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
    #endif
    
    RCTRootView *rootView = [[RCTRootView alloc] initWithBundleURL:jsCodeLocation
                                                        moduleName:@"App"
                                                     launchOptions:nil];
    self.view = rootView;
    
 }


@end

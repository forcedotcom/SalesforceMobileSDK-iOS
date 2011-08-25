#import <UIKit/UIKit.h>
#import "SFOAuthCoordinator.h"
#import "RestKit.h"


@interface AppDelegate : NSObject <UIApplicationDelegate, SFOAuthCoordinatorDelegate, UIAlertViewDelegate> {
    SFOAuthCoordinator *_coordinator;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UIViewController *viewController;
@property (nonatomic, retain) SFOAuthCoordinator *coordinator;


@end

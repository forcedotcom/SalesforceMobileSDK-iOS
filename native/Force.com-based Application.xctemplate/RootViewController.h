#import <UIKit/UIKit.h>
#import "SFRestAPI.h"

@interface RootViewController : UITableViewController <SFRestDelegate> {
    
    NSMutableArray *dataRows;
    IBOutlet UITableView *tableView;    

}

@property (nonatomic, retain) NSArray *dataRows;

@end
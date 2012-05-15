//
//  SFPasscodeiewController.h
//  CustomViews
//
//  Created by Kevin Hawkins on 5/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 Mode constants indicating whether to create or verify an existing passcode.
 */
typedef enum {
    SFPasscodeControllerModeCreate,
    SFPasscodeControllerModeVerify
} SFPasscodeControllerMode;

@interface SFPasscodeViewController : UIViewController <UITextFieldDelegate>

@property (readonly) NSInteger minPasscodeLength;
@property (readonly) SFPasscodeControllerMode mode;

- (id)initWithMode:(SFPasscodeControllerMode)mode;
- (id)initWithMode:(SFPasscodeControllerMode)mode minPasscodeLength:(NSInteger)minPasscodeLength;

@end

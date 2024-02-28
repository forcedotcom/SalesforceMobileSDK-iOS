#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RecaptchaActionType) {
  /** Indicates that the protected action is a Login workflow. */
  RecaptchaActionTypeLogin = 0,

  /** Indicates that the protected action is a Signup workflow. */
  RecaptchaActionTypeSignup = 1,

  /** When a custom action is specified, reCAPTCHA uses this value automatically. */
  RecaptchaActionTypeOther = 2,
};

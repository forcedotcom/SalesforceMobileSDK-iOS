#import <Foundation/Foundation.h>
#import "RecaptchaActionType.h"

#if __has_include("RecaptchaInterop/RCAActionProtocol.h")

@import RecaptchaInterop;
#define __HAS_RECAPTCHA_INTEROP_FRAMEWORK__

#endif

#ifdef __HAS_RECAPTCHA_INTEROP_FRAMEWORK__
/**
 * Action intended to be protected by reCAPTCHA. This object should be passed
 * to RecaptchaClient.execute.
 */
@interface RecaptchaAction : NSObject <RCAActionProtocol>
#else
/**
 * Action intended to be protected by reCAPTCHA. This object should be passed
 * to RecaptchaClient.execute.
 */
@interface RecaptchaAction : NSObject
#endif

/** Creates an object with a custom action from a String. */
- (instancetype _Nonnull)initWithCustomAction:(NSString *_Nonnull)customAction;

/** Indicates that the protected action is a Login workflow. */
@property(class, readonly, nonatomic) RecaptchaAction *_Nonnull login;

/** Indicates that the protected action is a Signup workflow. */
@property(class, readonly, nonatomic) RecaptchaAction *_Nonnull signup;

/** A String representing the action. */
@property(nonatomic, readonly) NSString *_Nonnull action;

/**
 * :nodoc:
 */
- (instancetype _Nonnull)init NS_UNAVAILABLE;

#pragma mark - Deprecated APIs and properties.

/** Action that is intended for reCAPTCHA to protect. */
@property(nonatomic, readonly) RecaptchaActionType actionType
    __attribute((deprecated("RecaptchaActionType is not used.")));

/** Extra parameters to send during call to execute. */
@property(nonatomic, readonly) NSDictionary *_Nullable extraParameters
    __attribute((deprecated("extraParameters is not used anywhere in the code")));

/** Creates an object with a predefined reCAPTCHA action. */
- (instancetype _Nonnull)initWithAction:(RecaptchaActionType)action
    __attribute((deprecated("Use initWithCustomAction instead.")));

/** A customized action. */
@property(nonatomic, readonly) NSString *_Nonnull customAction
    __attribute((deprecated("Use RecaptchaAction.action instead of customAction.")));

/** Creates an object with a predefined reCAPTCHA action and extra parameters. */
- (instancetype _Nonnull)initWithAction:(RecaptchaActionType)action
                        extraParameters:
                            (NSDictionary<NSString *, NSString *> *_Nullable)extraParameters
    __attribute((deprecated("Use initWithCustomAction instead.")));

/** Creates an object with a custom action from a String and extra parameters. */
- (instancetype _Nonnull)initWithCustomAction:(NSString *_Nonnull)customAction
                              extraParameters:
                                  (NSDictionary<NSString *, NSString *> *_Nullable)extraParameters
    __attribute((
        deprecated("Use initWithCustomAction(customAction:) without extraParameters instead.")));

@end

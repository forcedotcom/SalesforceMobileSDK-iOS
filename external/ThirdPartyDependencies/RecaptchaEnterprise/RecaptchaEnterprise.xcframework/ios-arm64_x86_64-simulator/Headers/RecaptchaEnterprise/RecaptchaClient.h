#import <Foundation/Foundation.h>

#if __has_include("RecaptchaInterop/RCARecaptchaClientProtocol.h")

@import RecaptchaInterop;
#define __HAS_RECAPTCHA_INTEROP_FRAMEWORK__

#endif

@class RecaptchaAction;
@class RecaptchaError;
@class RecaptchaToken;
@class RecaptchaVerificationHandler;

NS_ASSUME_NONNULL_BEGIN

#ifdef __HAS_RECAPTCHA_INTEROP_FRAMEWORK__
/** Interface to interact with reCAPTCHA. */
@interface RecaptchaClient : NSObject <RCARecaptchaClientProtocol>
#else
/** Interface to interact with reCAPTCHA. */
@interface RecaptchaClient : NSObject
#endif

/**
 * :nodoc:
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Executes reCAPTCHA on a user action.
 *
 * It is suggested the usage of 10 seconds for the timeout. The minimum value
 * is 5 seconds.
 *
 * @param action The user action to protect.
 * @param timeout Timeout for execute in milliseconds.
 * @param completion Callback function to return the execute result.
 */
- (void)execute:(RecaptchaAction *_Nonnull)action
    withTimeout:(double)timeout
     completion:(void (^)(NSString *_Nullable token, NSError *_Nullable error))completion
    NS_SWIFT_NAME(execute(withAction:withTimeout:completion:));

/**
 * Executes reCAPTCHA on a user action.
 *
 * This method throws a timeout exception after 10 seconds.
 *
 * @param action The user action to protect.
 * @param completion Callback function to return the execute result.
 */
- (void)execute:(RecaptchaAction *_Nonnull)action
     completion:(void (^)(NSString *_Nullable token, NSError *_Nullable error))completion
    NS_SWIFT_NAME(execute(withAction:completion:));

#pragma mark - Deprecated APIs and properties.

/**
 * Executes reCAPTCHA on a user action.
 *
 * This method throws a timeout exception after 10 seconds.
 *
 * @param action The user action to protect.
 * @param completionHandler Callback function to return the execute result.
 */
- (void)execute:(RecaptchaAction *_Nonnull)action
    completionHandler:(void (^)(RecaptchaToken *_Nullable recaptchaToken,
                                RecaptchaError *_Nullable error))completionHandler
    __attribute((deprecated("Use method execute(withTimeout:completionHandler) instead ")));

@end

NS_ASSUME_NONNULL_END

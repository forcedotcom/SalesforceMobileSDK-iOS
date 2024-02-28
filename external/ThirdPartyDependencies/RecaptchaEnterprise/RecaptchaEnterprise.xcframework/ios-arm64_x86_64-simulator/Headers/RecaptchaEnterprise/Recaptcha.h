#import <Foundation/Foundation.h>

@class RecaptchaClient;
@class RecaptchaError;

#if __has_include("RecaptchaInterop/RCARecaptchaProtocol.h")

@import RecaptchaInterop;
#define __HAS_RECAPTCHA_INTEROP_FRAMEWORK__

#endif

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(11.0))
#ifdef __HAS_RECAPTCHA_INTEROP_FRAMEWORK__
/** Interface to interact with reCAPTCHA. */
@interface Recaptcha : NSObject <RCARecaptchaProtocol>
#else
/** Interface to interact with reCAPTCHA. */
@interface Recaptcha : NSObject
#endif

/**
 * :nodoc:
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Builds a new reCAPTCHA Client for the given Site Key and timeout.
 *
 * The SDK supports one Site Key. Passing a different Site Key will
 * throw an exception.
 *
 * At least a 10000 millisecond timeout is suggested to allow for slow
 * networking, though in some cases longer timeouts may be necessary. The
 * minimum allowable value is 5000 milliseconds.
 *
 * @param siteKey reCAPTCHA Site Key for the app.
 * @param timeout Timeout for getClient in milliseconds.
 * @param completion Callback function to return the RecaptchaClient or an error.
 */
+ (void)getClientWithSiteKey:(nonnull NSString *)siteKey
                 withTimeout:(double)timeout
                  completion:(void (^)(RecaptchaClient *_Nullable recaptchaClient,
                                       NSError *_Nullable error))completion
    NS_SWIFT_NAME(getClient(withSiteKey:withTimeout:completion:));

/**
 * Builds a new reCAPTCHA Client for the given Site Key.
 *
 * The SDK supports one Site Key. Passing a different Site Key will
 * throw an exception.
 *
 * This method will timeout after 10 seconds.
 *
 * @param siteKey reCAPTCHA Site Key for the app.
 * @param completion Callback function to return the RecaptchaClient or an error.
 */
+ (void)getClientWithSiteKey:(nonnull NSString *)siteKey
                  completion:(void (^)(RecaptchaClient *_Nullable recaptchaClient,
                                       NSError *_Nullable error))completion
    NS_SWIFT_NAME(getClient(withSiteKey:completion:));

#pragma mark - Deprecated APIs and properties.

/**
 * Builds a new reCAPTCHA Client for the given SiteKey.
 *
 * This method will timeout after 10 seconds.
 *
 * @param siteKey reCAPTCHA Site Key for the app.
 * @param completionHandler Callback function to return the RecaptchaClient or an error.
 */
+ (void)getClientWithSiteKey:(NSString *)siteKey
           completionHandler:(void (^)(RecaptchaClient *_Nullable recaptchaClient,
                                       RecaptchaError *_Nullable error))completionHandler
    __attribute((deprecated("Use the new method getClient(withSiteKey:timeout:completion:)")))
    NS_SWIFT_NAME(getClient(siteKey:completionHandler:));

@end

NS_ASSUME_NONNULL_END

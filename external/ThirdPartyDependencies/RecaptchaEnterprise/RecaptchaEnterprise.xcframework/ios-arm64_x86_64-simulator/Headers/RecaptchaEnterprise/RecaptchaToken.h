#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Result of a successful execute operation.
 */
@interface RecaptchaToken : NSObject

/** Action that is intended for reCAPTCHA to protect. */
@property(nonatomic, readonly) NSString* recaptchaToken;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

//
//  SFTestContext.h
//  SalesforceCommonUtils
//
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

// This class is intended to be used to set the application in testing context or
// live context. It could be used by application to implement mock logic under 
// testing context so that application can be run without live connection


#import <UIKit/UIKit.h>

/**Helps determine whether we're currently running tests or not.
 */
@interface SFTestContext : NSObject {

}
/**Return YES if is running test
 */
+ (BOOL)isRunningTests;

/**Update SFTestContext to indicate whether it is in testing context or live context
 @param runningTests Yes if code is running under testing context
 */
+ (void)setIsRunningTests:(BOOL)runningTests;

/** Sets an arbitrary object into the test context
 @param object The object or nil to remove the object
 @param key The key
 */
+ (void)setObject:(id)object forKey:(id)key;

/** Returns an arbitrary object from the test context
 @param key The key
 @return The object
 */
+ (id)objectForKey:(id)key;

/** Removes all the stored objects
 */
+ (void)clearObjects;

@end

//
//  NSDictionary+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Sachin Desai on 5/2/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//


/**Extension to NSDictionary object
 
 Support retrieval of value use "/" separated hiearchy key
 */
@interface NSDictionary (SFAdditions)

/**Get object from NSDictionary with "/" separated path. 
 
 This function is similar to the built-in valueForKeyPath function except it handles special value like NSNULL and <nil> in the NSDictonary element value*
 
 @param path Path for the object to retrieve, use "/" to separate between levels. For example, root/child/valueKey will retrieve value from the root NSDictionary object to it's child dictionary's value with key "valueKey"  */
- (id) objectAtPath:(NSString *) path;

/**
 @return `nil` if the key has a value of `NSNull` or an NSString value of `<nil>`.
 */
- (id)nonNullObjectForKey:(id)key;

@end

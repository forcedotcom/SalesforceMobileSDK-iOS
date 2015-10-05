//
//  SFFileResourceUtility.h
//  SalesforceSearchSDK
//
//  Created by Riley Crebs on 7/9/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

@interface SFFileResourceUtility : NSObject

/**
 * @brief Reads a data object for the resource identified by the specified name and file extension.
 * @param name The name of the resource file. If name is an empty string or nil, returns the first file encountered of the supplied type.
 * @param fileExtention If extension is an empty string or nil, the extension is assumed not to exist and the file is the first file encountered that exactly matches name.
 * @param klass Class for the bundle where the resource should be read.
 * @return A data object for the resource file or nil if the file could not be located.
 */
- (NSData *)readDataForResource:(NSString *)name ofType:(NSString *)fileExtention class:(Class)klass;

/**
 * @brief Reads a JSON object for the resource identified by the specified name.
 * @param resource The name of the resource file. If name is an empty string or nil, returns the first file encountered of JSON type.
 * @param klass Class for the bundle where the resource should be read.
 * @error If an error occurs, upon return contains an NSError object that describes the problem.
 * @return A Foundation object, or nil if an error occurs.
 */
- (id)readJSONForResource:(NSString *)resource class:(Class)klass error:(NSError **)error;

@end

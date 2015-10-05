//
//  SalesforceCommonUtilsConstants.h
//  SalesforceCommonUtils
//
//  Created by Riley Crebs on 4/23/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#ifndef SalesforceCommonUtils_SalesforceCommonUtilsConstants_h
#define SalesforceCommonUtils_SalesforceCommonUtilsConstants_h

/** Returns a size with the `aspect ratio` within the bounding size.
 
 @param aspectRatio Size with desired aspect ratio
 @param boundingSize Size with the desized bounds
 @return The `aspect ratio` within the bounding size.
 */
CG_INLINE CGSize
CGSizeAspectFit(CGSize aspectRatio, CGSize boundingSize) {
    float mW = boundingSize.width / aspectRatio.width;
    float mH = boundingSize.height / aspectRatio.height;
    if( mH < mW )
        boundingSize.width = boundingSize.height / aspectRatio.height * aspectRatio.width;
    else if( mW < mH )
        boundingSize.height = boundingSize.width / aspectRatio.width * aspectRatio.height;
    return boundingSize;
}

#define BLOCK(b, ...) if (b) { b(__VA_ARGS__); }
#endif

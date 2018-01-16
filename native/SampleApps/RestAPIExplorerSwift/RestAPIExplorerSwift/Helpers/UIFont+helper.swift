//
//  UIFont+helper.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 12/6/17.
//  Copyright © 2017 Salesforce. All rights reserved.
//

import UIKit

extension UIFont {
    class func appRegularFont(_ size:CGFloat) -> UIFont? {
        return UIFont(name: "SalesforceSans-Regular", size: size)
    }
    
    class func appBoldFont(_ size:CGFloat) -> UIFont? {
        return UIFont(name: "SalesforceSans-Bold", size: size)
    }
    
    class func appLightFont(_ size:CGFloat) -> UIFont? {
        return UIFont(name: "SalesforceSans-Light", size: size)
    }
}

//
//  UIColors+helper.swift
//  RestAPIExplorerSwift
//
//  Created by Nicholas McDonald on 11/29/17.
//  Copyright © 2017 Salesforce. All rights reserved.
//

import UIKit

extension UIColor {
    
    class var appDarkBlue:UIColor {
        get {
            return UIColor(displayP3Red: 20.0/255.0, green: 50.0/255.0, blue: 92.0/255.0, alpha: 1.0)
        }
    }
    
    class var appBlue:UIColor {
        get {
            return UIColor(displayP3Red: 0.0/255.0, green: 112.0/255.0, blue: 210.0/255.0, alpha: 1.0)
        }
    }
    
    class var detailViewControllerBackground:UIColor {
        get {
            return UIColor(displayP3Red: 250.0/255.0, green: 251/255.0, blue: 253.0/255.0, alpha: 1.0)
        }
    }
    
    class var appSeparator:UIColor {
        get {
            return UIColor(displayP3Red: 22.0/255.0, green: 50.0/255.0, blue: 92.0/255.0, alpha: 0.1)
        }
    }
    
    class var contactCellTitle:UIColor {
        get {
            return UIColor(displayP3Red: 42.0/255.0, green: 66.0/255.0, blue: 108.0/255.0, alpha: 1.0)
        }
    }
    
    class var contactCellSubtitle:UIColor {
        get {
            return UIColor(displayP3Red: 168.0/255.0, green: 183.0/255.0, blue: 199.0/255.0, alpha: 1.0)
        }
    }
    
    class var contactCellDeletedBackground:UIColor {
        get {
            return UIColor(displayP3Red: 194.0/255.0, green: 57.0/255.0, blue: 52.0/255.0, alpha: 0.3)
        }
    }
    
    class var labelText:UIColor {
        get {
            return UIColor(displayP3Red: 84.0/255.0, green: 105.0/255.0, blue: 141.0/255.0, alpha: 1.0)
        }
    }
    
    class var fieldText:UIColor {
        get {
            return UIColor(displayP3Red: 42.0/255.0, green: 66.0/255.0, blue: 108.0/255.0, alpha: 1.0)
        }
    }
    
    class var destructiveButton:UIColor {
        get {
            return UIColor(displayP3Red: 194.0/255.0, green: 57.0/255.0, blue: 52.0/255.0, alpha: 1.0)
        }
    }
    
    
}

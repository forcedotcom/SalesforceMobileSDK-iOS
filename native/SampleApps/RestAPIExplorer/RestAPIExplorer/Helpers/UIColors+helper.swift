/*
 UIColors+helper.swift
 RestAPIExplorerSwift

 Created by Nicholas McDonald on 11/29/17.

 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit

extension UIColor {
    
    class var appDarkBlue: UIColor {
        return UIColor(displayP3Red: 20.0/255.0, green: 50.0/255.0, blue: 92.0/255.0, alpha: 1.0)
    }

    class var appTextBlue: UIColor {
       return UIColor(displayP3Red: 84.0/255.0, green: 105.0/255.0, blue: 141.0/255.0, alpha: 1.0)
    }

    class var appTextFieldBlue: UIColor {
        return UIColor(displayP3Red: 42.0/255.0, green: 66.0/255.0, blue: 108.0/255.0, alpha: 1.0)
    }

    class var appTextFieldBorder: UIColor {
        return UIColor.separator
    }
    
    class var appViewBorder: UIColor {
        return UIColor.separator
    }

    class var appButton: UIColor {
        return UIColor.systemBlue
    }
    
    class var appGroupedBackground: UIColor {
        return UIColor.systemGroupedBackground
    }
    
    class var appSecondarySystemGroupedBackground: UIColor {
        if #available(iOS 13, *) {
            return UIColor.secondarySystemGroupedBackground
        }
        return UIColor.white
    }

    class var appContentBackground: UIColor {
        let lightStyleColor = UIColor(displayP3Red: 224.0/255.0, green: 229.0/255.0, blue: 238.0/255.0, alpha: 1.0)
        return UIColor.sfsdk_color(forLightStyle: lightStyleColor, darkStyle: UIColor.secondarySystemBackground)
    }
    
    class var appTextViewYellowBackground: UIColor {
        let lightStyleColor = UIColor(displayP3Red: 250.0/255.0, green: 255.0/255.0, blue: 189.0/255.0, alpha: 1.0)
        let darkStyleColor = UIColor(displayP3Red: 249.0/255.0, green: 214.0/255.0, blue: 74/255.0, alpha: 0.35)
        return UIColor.sfsdk_color(forLightStyle: lightStyleColor, darkStyle: darkStyleColor)
    }
    
    class var appTextField: UIColor {
        return UIColor.sfsdk_color(forLightStyle: UIColor.appTextFieldBlue, darkStyle: UIColor.label)
    }
    
    class var appLabel: UIColor {
        return UIColor.sfsdk_color(forLightStyle: UIColor.appTextBlue, darkStyle: UIColor.label)
    }
}

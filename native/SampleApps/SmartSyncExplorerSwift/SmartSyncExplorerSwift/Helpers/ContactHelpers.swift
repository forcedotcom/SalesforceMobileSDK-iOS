//
//  ContactHelpers.swift
//  SmartSyncExplorerSwift
//
//  Created by Nicholas McDonald on 1/22/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import Foundation
import SmartSyncExplorerCommon

class ContactHelper {
    static func nameStringFromContact(_ obj:ContactRecord) -> String {
        let firstName = obj.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = obj.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if firstName == nil && lastName == nil {
            return ""
        } else if firstName == nil && lastName != nil {
            return lastName!
        } else if firstName != nil && lastName == nil {
            return firstName!
        } else {
            return "\(firstName!) \(lastName!)"
        }
    }
    
    static func titleStringFromContact(_ obj:ContactRecord) -> String {
        let title = obj.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title != nil ? title! : ""
    }
    
    static func initialsStringFromContact(_ obj:ContactRecord) -> String {
        let firstName = obj.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = obj.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var initialsString = ""
        if let first = firstName, first.count > 0, let firstChar = first.first {
            initialsString.append(firstChar)
        }
        
        if let last = lastName, last.count > 0, let lastChar = last.first {
            initialsString.append(lastChar)
        }
        
        return initialsString
    }
    
    static func colorFromContact(_ obj:ContactRecord) -> UIColor {
        guard let lastName = obj.lastName?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return UIColor.white
        }
        var codeSeedFromName:UInt32 = 0
        for (_, element) in lastName.unicodeScalars.enumerated() {
            codeSeedFromName = codeSeedFromName + element.value
        }
        
        let index = codeSeedFromName % UInt32(Constants.ContactColorCodes.count)
        let hexValue = Constants.ContactColorCodes[Int(index)]
        return ContactHelper.colorFrom(hexValue)
    }
    
    static func colorFrom(_ hex:UInt32) -> UIColor {
        return UIColor(displayP3Red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
                       green: CGFloat((hex & 0xFF00) >> 8) / 255.0,
                       blue: CGFloat(hex & 0xFF) / 255.0,
                       alpha: 1.0)
    }
    
    static func initialsImage(_ color:UIColor, initials:String) -> UIImage? {
        UIGraphicsBeginImageContext(CGSize(width: Constants.ContactCellImageSize, height: Constants.ContactCellImageSize))
        let fillColor = color.withAlphaComponent(0.1)
        guard let ctx = UIGraphicsGetCurrentContext() else {return UIImage()}
        UIGraphicsPushContext(ctx)
        let radius = Constants.ContactCellImageSize/2.0
        let center = CGPoint(x: radius, y: radius)
        ctx.setFillColor(fillColor.cgColor)
        ctx.beginPath()
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.fillPath()
        
        let string = initials as NSString
        let attribs:[NSAttributedStringKey: Any] = [NSAttributedStringKey.foregroundColor: color, NSAttributedStringKey.font: UIFont.appRegularFont(19.0)!]
        let size = string.size(withAttributes: attribs)
        let rect = CGRect(x: center.x - (size.width / 2.0), y: center.y - (size.height / 2.0), width: size.width, height: size.height)
        string.draw(in: rect, withAttributes: attribs)
        
        UIGraphicsPopContext()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}

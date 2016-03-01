//
//  PageThatWaits.swift
//  Chatter
//
//  Created by Eric Engelking on 10/16/15.
//  Copyright © 2015 Salesforce.com. All rights reserved.
//

import Foundation
import XCTest

protocol PageThatWaits {
    func waitForPageLoaded()
    func waitForPageInvalid()
}
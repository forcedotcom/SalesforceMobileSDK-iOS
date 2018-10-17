//
//  main.swift
//  RestAPIExplorer
//
//  Created by Raj Rao on 10/15/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

import UIKit
import SalesforceSDKCore

UIApplicationMain(
    CommandLine.argc,
    UnsafeMutableRawPointer(CommandLine.unsafeArgv)
        .bindMemory(
            to: UnsafeMutablePointer<Int8>.self,
            capacity: Int(CommandLine.argc)
    ),
    NSStringFromClass(SFApplication.self),
    NSStringFromClass(AppDelegate.self)
)

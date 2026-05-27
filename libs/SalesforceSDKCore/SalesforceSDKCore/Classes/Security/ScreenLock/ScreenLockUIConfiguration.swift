//
//  ScreenLockUIConfiguration.swift
//  SalesforceSDKCore
//
//  Created by Claude on 5/21/26.
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

/// Configuration for the appearance of the screen lock view.
///
/// Set this on ``ScreenLockManager/configuration`` to customize the lock screen's visual elements.
@objc(SFSDKScreenLockUIConfiguration)
public class ScreenLockUIConfiguration: NSObject {
    /// The icon displayed at the center of the lock screen.
    ///
    /// When `nil` (the default), the lock screen uses the app's primary icon from
    /// `CFBundleIcons`, falling back to the Salesforce logo if unavailable.
    @objc public var icon: UIImage?

    /// The size at which the icon is rendered.
    ///
    /// Defaults to 125x125 points. The image will be scaled using aspect-fit to this size.
    @objc public var iconSize = CGSize(width: 125, height: 125)

    /// Creates a configuration with default values.
    ///
    /// The default configuration reproduces the existing lock screen appearance:
    /// - Icon: app's primary icon or Salesforce logo
    /// - Size: 125x125 points
    @objc public override init() {
        self.icon = nil
        super.init()
    }
}

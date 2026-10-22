/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 
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

import XCTest
@testable import SalesforceSDKCore

private final class HardwareDevice: UIDevice {
    var identifier = ""
    var simulated = false

    override func sfsdk_platform() -> String? { identifier }
    override func sfsdk_isSimulator() -> Bool { simulated }
}

final class UIDeviceHardwareTests: XCTestCase {
    // Audited against DeviceKit 19528aa and Apple product specifications.
    private let models: [(name: String, identifiers: String, neuralEngine: Bool)] = [
        ("iPhone SE (2nd generation)", "iPhone12,8", true),
        ("iPhone SE (3rd generation)", "iPhone14,6", true),
        ("iPhone XR", "iPhone11,8", true),
        ("iPhone XS", "iPhone11,2", true),
        ("iPhone XS Max", "iPhone11,4 iPhone11,6", true),
        ("iPhone 11", "iPhone12,1", true),
        ("iPhone 11 Pro", "iPhone12,3", true),
        ("iPhone 11 Pro Max", "iPhone12,5", true),
        ("iPhone 12 mini", "iPhone13,1", true),
        ("iPhone 12", "iPhone13,2", true),
        ("iPhone 12 Pro", "iPhone13,3", true),
        ("iPhone 12 Pro Max", "iPhone13,4", true),
        ("iPhone 13 mini", "iPhone14,4", true),
        ("iPhone 13", "iPhone14,5", true),
        ("iPhone 13 Pro", "iPhone14,2", true),
        ("iPhone 13 Pro Max", "iPhone14,3", true),
        ("iPhone 14", "iPhone14,7", true),
        ("iPhone 14 Plus", "iPhone14,8", true),
        ("iPhone 14 Pro", "iPhone15,2", true),
        ("iPhone 14 Pro Max", "iPhone15,3", true),
        ("iPhone 15", "iPhone15,4", true),
        ("iPhone 15 Plus", "iPhone15,5", true),
        ("iPhone 15 Pro", "iPhone16,1", true),
        ("iPhone 15 Pro Max", "iPhone16,2", true),
        ("iPhone 16", "iPhone17,3", true),
        ("iPhone 16 Plus", "iPhone17,4", true),
        ("iPhone 16 Pro", "iPhone17,1", true),
        ("iPhone 16 Pro Max", "iPhone17,2", true),
        ("iPhone 16e", "iPhone17,5", true),
        ("iPhone 17", "iPhone18,3", true),
        ("iPhone 17 Pro", "iPhone18,1", true),
        ("iPhone 17 Pro Max", "iPhone18,2", true),
        ("iPhone Air", "iPhone18,4", true),
        ("iPhone 17e", "iPhone18,5", true),
        ("iPhone 18 Pro", "iPhone19,2", true),
        ("iPhone 18 Pro Max", "iPhone19,3 iPhone19,7", true),
        ("iPad (7th generation)", "iPad7,11 iPad7,12", false),
        ("iPad (8th generation)", "iPad11,6 iPad11,7", true),
        ("iPad (9th generation)", "iPad12,1 iPad12,2", true),
        ("iPad (10th generation)", "iPad13,18 iPad13,19", true),
        ("iPad (A16)", "iPad15,7 iPad15,8", true),
        ("iPad mini (5th generation)", "iPad11,1 iPad11,2", true),
        ("iPad mini (6th generation)", "iPad14,1 iPad14,2", true),
        ("iPad mini (A17 Pro)", "iPad16,1 iPad16,2", true),
        ("iPad Air (3rd generation)", "iPad11,3 iPad11,4", true),
        ("iPad Air (4th generation)", "iPad13,1 iPad13,2", true),
        ("iPad Air (5th generation)", "iPad13,16 iPad13,17", true),
        ("iPad Air 11-inch (M2)", "iPad14,8 iPad14,9", true),
        ("iPad Air 13-inch (M2)", "iPad14,10 iPad14,11", true),
        ("iPad Air 11-inch (M3)", "iPad15,3 iPad15,4", true),
        ("iPad Air 13-inch (M3)", "iPad15,5 iPad15,6", true),
        ("iPad Air 11-inch (M4)", "iPad16,8 iPad16,9", true),
        ("iPad Air 13-inch (M4)", "iPad16,10 iPad16,11", true),
        ("iPad Pro (11-inch, 1st generation)", "iPad8,1 iPad8,2 iPad8,3 iPad8,4", true),
        ("iPad Pro (11-inch, 2nd generation)", "iPad8,9 iPad8,10", true),
        ("iPad Pro (11-inch, 3rd generation)", "iPad13,4 iPad13,5 iPad13,6 iPad13,7", true),
        ("iPad Pro (11-inch, 4th generation)", "iPad14,3 iPad14,4", true),
        ("iPad Pro (12.9-inch, 3rd generation)", "iPad8,5 iPad8,6 iPad8,7 iPad8,8", true),
        ("iPad Pro (12.9-inch, 4th generation)", "iPad8,11 iPad8,12", true),
        ("iPad Pro (12.9-inch, 5th generation)", "iPad13,8 iPad13,9 iPad13,10 iPad13,11", true),
        ("iPad Pro (12.9-inch, 6th generation)", "iPad14,5 iPad14,6", true),
        ("iPad Pro 11-inch (M4)", "iPad16,3 iPad16,4", true),
        ("iPad Pro 13-inch (M4)", "iPad16,5 iPad16,6", true),
        ("iPad Pro 11-inch (M5)", "iPad17,1 iPad17,2", true),
        ("iPad Pro 13-inch (M5)", "iPad17,3 iPad17,4", true),
        ("Apple TV HD", "AppleTV5,3", false),
        ("Apple TV 4K (1st generation)", "AppleTV6,2", false),
        ("Apple TV 4K (2nd generation)", "AppleTV11,1", false),
        ("Apple TV 4K (3rd generation)", "AppleTV14,1", false),
    ]

    func test_givenKnownHardware_whenLookingUpPlatform_thenReturnsProductName() {
        let device = HardwareDevice()
        for model in models {
            for identifier in model.identifiers.split(separator: " ") {
                device.identifier = String(identifier)
                XCTAssertEqual(device.sfsdk_platformString(), model.name, String(identifier))
            }
        }
    }

    func test_givenKnownHardware_whenCheckingNeuralEngine_thenReturnsChipCapability() {
        let device = HardwareDevice()
        for model in models {
            for identifier in model.identifiers.split(separator: " ") {
                device.identifier = String(identifier)
                XCTAssertEqual(device.sfsdk_hasNeuralEngine(), model.neuralEngine, String(identifier))
            }
        }
    }

    func test_givenExistingHardware_whenLookingUpPlatform_thenPreservesEnumValues() {
        let expected: [String: UInt] = [
        "iPhone12,8": 6,
        "iPhone14,6": 7,
        "iPhone11,8": 8,
        "iPhone11,2": 9,
        "iPhone11,4": 10,
        "iPhone11,6": 10,
        "iPhone12,1": 11,
        "iPhone12,3": 12,
        "iPhone12,5": 13,
        "iPhone13,1": 14,
        "iPhone13,2": 15,
        "iPhone13,3": 16,
        "iPhone13,4": 17,
        "iPhone14,4": 18,
        "iPhone14,5": 19,
        "iPhone14,2": 20,
        "iPhone14,3": 21,
        "iPhone14,7": 22,
        "iPhone14,8": 23,
        "iPhone15,2": 24,
        "iPhone15,3": 25,
        "iPhone15,4": 26,
        "iPhone15,5": 27,
        "iPhone16,1": 28,
        "iPhone16,2": 29,
        "iPhone17,1": 30,
        "iPhone17,2": 31,
        "iPhone17,3": 32,
        "iPhone17,4": 33,
        "iPad7,11": 39,
        "iPad7,12": 39,
        "iPad8,1": 48,
        "iPad8,2": 48,
        "iPad8,3": 48,
        "iPad8,4": 48,
        "iPad8,5": 44,
        "iPad8,6": 44,
        "iPad8,7": 44,
        "iPad8,8": 44,
        "iPad8,9": 49,
        "iPad8,10": 49,
        "iPad8,11": 45,
        "iPad8,12": 45,
        "iPad11,3": 36,
        "iPad11,4": 36,
        "iPad11,1": 34,
        "iPad11,2": 34,
        "iPad11,6": 40,
        "iPad11,7": 40,
        "iPad12,1": 41,
        "iPad12,2": 41,
        "iPad13,1": 37,
        "iPad13,2": 37,
        "iPad13,4": 50,
        "iPad13,5": 50,
        "iPad13,6": 50,
        "iPad13,7": 50,
        "iPad13,8": 46,
        "iPad13,9": 46,
        "iPad13,10": 46,
        "iPad13,11": 46,
        "iPad13,16": 38,
        "iPad13,17": 38,
        "iPad13,18": 42,
        "iPad13,19": 42,
        "iPad14,1": 35,
        "iPad14,2": 35,
        "iPad14,3": 51,
        "iPad14,4": 51,
        "iPad14,5": 47,
        "iPad14,6": 47,
        "iPad14,8": 52,
        "iPad14,9": 52,
        "iPad14,10": 53,
        "iPad14,11": 53,
        "iPad16,1": 54,
        "iPad16,2": 54,
        "iPad16,3": 55,
        "iPad16,4": 55,
        "iPad16,5": 56,
        "iPad16,6": 56,
        "AppleTV5,3": 57,
        "AppleTV6,2": 58,
        "AppleTV11,1": 59,
        "AppleTV14,1": 60,
        ]
        let device = HardwareDevice()
        for (identifier, rawValue) in expected {
            device.identifier = identifier
            XCTAssertEqual(device.sfsdk_platformType().rawValue, rawValue, identifier)
        }
    }

    func test_givenUnknownHardware_whenLookingUpPlatform_thenKeepsFamilyFallback() {
        let device = HardwareDevice()
        for (identifier, name) in [("iPhone99,1", "Unknown iPhone"),
                                   ("iPad99,1", "Unknown iPad"),
                                   ("AppleTV99,1", "Unknown Apple TV"),
                                   ("future-device", "Unknown iOS device")] {
            device.identifier = identifier
            XCTAssertEqual(device.sfsdk_platformString(), name)
            XCTAssertFalse(device.sfsdk_hasNeuralEngine())
        }
    }

    func test_givenSimulator_whenLookingUpPlatform_thenKeepsSimulatorName() {
        let device = HardwareDevice()
        device.identifier = "arm64"
        device.simulated = true
        let expected = UIDevice.current.userInterfaceIdiom == .pad ? "iPad Simulator" : "iPhone Simulator"
        XCTAssertEqual(device.sfsdk_platformString(), expected)
        XCTAssertFalse(device.sfsdk_hasNeuralEngine())
    }
}

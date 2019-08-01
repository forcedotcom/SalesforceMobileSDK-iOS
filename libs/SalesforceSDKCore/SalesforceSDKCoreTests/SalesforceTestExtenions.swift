/*
 SalesforceTestExtenions.swift
 SalesforceSDKCoreTests
 
 Created by Raj Rao on 7/25/19.
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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


import Foundation
import XCTest

// Good suggestion to avoid force unwraps in tests.
// https://www.swiftbysundell.com/posts/avoiding-force-unwrapping-in-swift-unit-tests

extension XCTestCase {
    // We conform to LocalizedError in order to be able to output
    // a nice error message.
    private struct RequireError<T>: LocalizedError {
        let file: StaticString
        let line: UInt
        
        // It's important to implement this property, otherwise we won't
        // get a nice error message in the logs if our tests start to fail.
        var errorDescription: String? {
            return "😱 Required value of type \(T.self) was nil at line \(line) in file \(file)."
        }
    }
    
    // Using file and line lets us automatically capture where
    // the expression took place in our source code.
    func require<T>(_ expression: @autoclosure () -> T?,
                    file: StaticString = #file,
                    line: UInt = #line) throws -> T {
        guard let value = expression() else {
            throw RequireError<T>(file: file, line: line)
        }
        
        return value
    }
}

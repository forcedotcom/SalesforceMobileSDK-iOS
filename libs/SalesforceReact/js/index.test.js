/*
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

import React from 'react';
import { assert } from 'chai'; 
import { AppRegistry, NativeModules, View } from 'react-native';
const { TestModule } = NativeModules;
const createReactClass = require('create-react-class');
import {oauth, net, smartstore, smartsync} from 'react-native-force';


//
// Helper code - belongs in helper class
//

const componentForTest = (test) => {
    return createReactClass({
        componentDidMount() {
            if (test() != false) {
                TestModule.markTestPassed(true);
            }
        },
        
        render() {
            return (<View/>);
        }            
    });
};

const registerTest = (test) => {
    AppRegistry.registerComponent(test.name.substring("test".length), () => componentForTest(test));
};

//
// Harness Tests
//

testPassing = () => {
    assert(true, "testPassing should have succeeded");
};

testFailing = () => {
    assert(false, "testFailing failed not surprisingly");
};

testAsyncPassing = () => {
    oauth.getAuthCredentials(
        (creds) => { TestModule.markTestPassed(true); },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testAsyncFailing = () => {
    oauth.getAuthCredentials(
        (creds) => { throw "testAsyncFailing made-up exception"; },
        (error) => { throw error; }
    );
    
    return false; // not done
};

//
// Oauth tests
//

testGetAuthCredentials = () => {
    oauth.getAuthCredentials(
        (creds) => {
            assert.deepEqual(Object.keys(creds).sort(), ["accessToken","clientId","instanceUrl","loginUrl","orgId","refreshToken","userAgent","userId"], 'Wrong keys in credentials');
            TestModule.markTestPassed(true);
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};


//
// Tests registration
//

registerTest(testPassing);
registerTest(testFailing);
registerTest(testAsyncPassing);
registerTest(testAsyncFailing);
registerTest(testGetAuthCredentials);

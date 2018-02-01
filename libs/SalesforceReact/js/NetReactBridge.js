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

'use strict';


var React = require('react');
var ReactNative = require('react-native');
var {
  Text,
  View,
} = ReactNative;
var { TestModule } = ReactNative.NativeModules;

import {smartstore, smartsync} from 'react-native-force';


class NetReactBridgeTests extends React.Component {

  constructor(props) {
    super(props);
    this.state = {done: false};
  }

  componentDidMount() {
      this.runTest();
  }

  markDone() {
    this.setState({done: true}, () => {
    });
  }

  _registerGlobalSoupWithName(soupName, callback) {
    if(soupName){
      smartstore.registerSoup(true,
        soupName,
        [ {path:"Id", type:"string"},
          {path:"FirstName", type:"full_text"},
          {path:"LastName", type:"full_text"},
          {path:"__local__", type:"string"}
        ],
        () => {
            if(callback){
              callback()
            }
          }
       );
    }
  }

  _checkIfExistsGlobalSoupWithName(soupName, callback) {
    smartstore.soupExists(true,soupName,callback)
  }

  testRegisterGlobalSoup() {
    const soupName = 'contacts'
    this._registerGlobalSoupWithName(soupName,()=>{
      this._checkIfExistsGlobalSoupWithName(soupName,()=>{
        this.markDone()
      })
    })
  }

  runTest() {
    this.testRegisterGlobalSoup();
  }

  render() {
    return (
      <View style={{backgroundColor: 'white', padding: 40}}>
        <Text>
          {this.constructor.displayName + ': '}
          {this.state.done ? 'Done' : 'Testing...'}
        </Text>
        {this.state.done ? <Text accessibilityLabel="testResult" accessible={true}>NetReactBridgeTests</Text> : <Text>Testing...</Text>}

      </View>
    );
  }
}

NetReactBridgeTests.displayName = 'NetReactBridgeTests';

module.exports = NetReactBridgeTests;

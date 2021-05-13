//
//  KeyValueEncryptedFileStoreInpector.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 10/1/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
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

import SwiftUI

private let GLOBAL = " (global)"

struct KeyValueEncryptedFileStoreInspector: View {
    var stores = getStores()
    @State private var selectedIndex = 0
    @State private var key: String = ""
    @State private var keyValueList: [KeyValuePair] = []
    @State private var keyNotFoundAlert: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Form {
                    Picker(selection: $selectedIndex, label: Text("Store")) {
                        ForEach(0 ..< stores.count) {
                            Text(self.stores[$0])
                        }
                    }
                    HStack {
                        TextField("Exact or partial key (for partial use *)", text: $key)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                        Button("Get Value(s)", action: {
                            self.getValues(typedKey: self.key)
                        }).alert(isPresented: self.$keyNotFoundAlert) {
                            Alert(title: Text("No matching key found in selected store."))
                        }
                    }
                }.frame(height: 150, alignment: .center)
                
                List {
                    ForEach(keyValueList, id: \.self) { pair in
                        VStack {
                            Text(pair.value)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .contextMenu {
                                        Button(action: {
                                            UIPasteboard.general.string = pair.value
                                        }) {
                                            Text("Copy value to clipboard")
                                            Image(systemName: "doc.on.doc")
                                        }
                                        Button(action: {
                                            UIPasteboard.general.string = pair.key
                                        }) {
                                            Text("Copy key to clipboard")
                                            Image(systemName: "doc.on.doc")
                                        }
                                     }
                            Text(pair.key)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }.navigationBarTitle(Text("Key-Value Store Inspector"), displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func getValues(typedKey: String) {
        let stores = getStores()
        var currentStore: KeyValueEncryptedFileStore
        var currentStoreName: String
        
        keyValueList.removeAll()
        
        if stores.isEmpty {
            keyNotFoundAlert = true
            return
        }
        
        currentStoreName = getStores()[selectedIndex]
        if currentStoreName.hasSuffix(GLOBAL) {
            // Remove global postfix added to label to get actaul store name
            let start = currentStoreName.startIndex
            let globalCutoff = currentStoreName.count - GLOBAL.count
            let end = currentStoreName.index(start, offsetBy: globalCutoff)
            
            currentStoreName = String(currentStoreName[start..<end])
            currentStore = KeyValueEncryptedFileStore.sharedGlobal(withName: currentStoreName)!
        } else {
            currentStore = KeyValueEncryptedFileStore.shared(withName: currentStoreName)!
        }
        
        // Return matching entries if v2 kv store AND key contains a *
        if (currentStore.storeVersion == 2 && typedKey.contains("*")) {
            let allKeys = currentStore.allKeys()
            let allKeysSorted = allKeys == nil ? [] : allKeys!.sorted()
            for key in allKeysSorted {
                if (matches(typedKey: typedKey, key: key)) {
                    keyValueList.append(KeyValuePair(key: key, value: currentStore[key]!))
                }
            }
        }
        // Otherwise simply lookup typedKey
        else {
            let value = currentStore[typedKey]
            if (value != nil) {
                keyValueList.insert(KeyValuePair(key: typedKey, value: value!), at: 0)
            }
        }
        
        if (keyValueList.count == 0) {
            keyNotFoundAlert = true
        }
    }
    
}

func matches(typedKey: String, key: String) -> Bool {
    if (typedKey.contains("*")) {
        let regex = try! NSRegularExpression(pattern: "^" + typedKey.replacingOccurrences(of: "*", with: ".*") + "$")
        let range = NSRange(location: 0, length: key.utf16.count)
        return regex.firstMatch(in: key, options: [], range: range) != nil
    } else {
        return key == typedKey;
    }
}

func getStores() -> [String] {
    var stores = KeyValueEncryptedFileStore.allNames()
    for globalStore in KeyValueEncryptedFileStore.allGlobalNames() {
        stores.append(globalStore + GLOBAL)
    }
    return stores
}

struct KeyValuePair: Hashable {
    var key: String
    var value: String
}

struct KeyValueEncryptedFileStoreInpector_Previews: PreviewProvider {
    static var previews: some View {
        KeyValueEncryptedFileStoreInspector()
    }
}
    

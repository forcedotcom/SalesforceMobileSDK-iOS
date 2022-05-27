//
//  CollectionSyncUpTarget.swift
//  MobileSync
//
//  Created by Wolfgang Mathurin on 5/26/22.
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
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

import Foundation
import SalesforceSDKCore
import Combine


//
// Subclass of SyncUpTarget that batches create/update/delete operations by using sobject collection apis
//
@objc(SFCollectionSyncUpTarget)
public class CollectionSyncUpTarget: BatchSyncUpTarget {
    
    static let maxRecordsCollectionAPI:UInt = 200
    
    override public class func build(dict: Dictionary<AnyHashable, Any>?) -> Self {
        return self.init(dict: dict ?? Dictionary())
    }
        
    override public convenience init() {
        self.init(createFieldlist:nil, updateFieldlist:nil, maxBatchSize:nil)
    }

    override public convenience init(createFieldlist: Array<String>?, updateFieldlist: Array<String>?) {
        self.init(createFieldlist:createFieldlist, updateFieldlist:updateFieldlist, maxBatchSize:nil)
    }
    
    // Construct CollectionSyncUpTarget with a different maxBatchSize and id/modifiedDate/externalId fields
    override public init(createFieldlist: Array<String>?, updateFieldlist: Array<String>?, maxBatchSize:NSNumber?) {
        super.init(createFieldlist:createFieldlist, updateFieldlist:updateFieldlist, maxBatchSize: maxBatchSize)
    }
 
    // Construct SyncUpTarget from json
    override required public init(dict: Dictionary<AnyHashable, Any>) {
        super.init(dict: dict);
    }

    override func maxAPIBatchSize() -> UInt {
        return CollectionSyncUpTarget.maxRecordsCollectionAPI
    }
    
    override func sendRecordRequests(_ syncManager:SyncManager, recordRequests:Array<CompositeRequestHelper.RecordRequest>,
                            onComplete: @escaping OnSendCompleteCallback, onFail: @escaping OnFailCallback) {
        
        CompositeRequestHelper.sendAsCollectionRequests(syncManager, allOrNone: false, recordRequests: recordRequests, onComplete: onComplete, onFail: onFail)
    }
}

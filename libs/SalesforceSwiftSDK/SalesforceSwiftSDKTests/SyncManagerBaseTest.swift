/*
 SyncManagerBaseTest
 Created by Raj Rao on 02/03/18.
 
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

import XCTest
import SalesforceSDKCore
import SmartStore
import SmartSync
import PromiseKit
@testable import SalesforceSwiftSDK

//Global Constants
let TYPE = "type"
let ATTRIBUTES = "attributes"
let RECORDS = "records"
let LOCAL_ID_PREFIX = "local_"
let REMOTELY_UPDATED = "_r_upd"
let LOCALLY_UPDATED = "_l_upd"
let CONTACT_TYPE = "Contact"
let CONTACTS_SOUP = "contacts"

let ID = "Id"
let DESCRIPTION = "Description"
let FIRST_NAME = "FirstName"
let LAST_NAME = "LastName"
let TITLE = "Title"
let MOBILE_PHONE = "MobilePhone"
let EMAIL = "Email"
let HOME_PHONE = "HomePhone"
var contactFieldList = [ID,FIRST_NAME,LAST_NAME,DESCRIPTION,TITLE,MOBILE_PHONE,EMAIL,HOME_PHONE]
var contactSyncFieldList = [FIRST_NAME,LAST_NAME,DESCRIPTION,TITLE,MOBILE_PHONE,EMAIL,HOME_PHONE]

enum TestError : Error {
    case InitializationError
}

class SyncManagerBaseTest: SalesforceSwiftSDKBaseTest {
    
    var currentUser: SFUserAccount?
    var syncManager: SFSmartSyncSyncManager?
    var store: SFSmartStore?
    var storeClient: SFSmartStoreClient?
    var globalSyncManager: SFSmartSyncSyncManager?
    var globalStore: SFSmartStore?
    
    override class func setUp() {
        super.setUp()
       
    }
    
    override func setUp() {
        super.setUp()
        currentUser = SFUserAccountManager.sharedInstance().currentUser
        store = SFSmartStore.sharedStore(withName: kDefaultSmartStoreName, user: currentUser!) as?  SFSmartStore
        syncManager = SFSmartSyncSyncManager.sharedInstance(for:store!)
        
        globalStore = SFSmartStore.sharedGlobalStore(withName: kDefaultSmartStoreName) as? SFSmartStore
        globalSyncManager = SFSmartSyncSyncManager.sharedInstance(for: globalStore!)
    }
    
    override func tearDown() {
        // User and managers tear down
        globalStore!.clearSoup(kSFSyncStateSyncsSoupName)
        store!.clearSoup(kSFSyncStateSyncsSoupName)
        super.tearDown()
    }
    
    func deleteSyncs() {
        self.store?.clearSoup(kSFSyncStateSyncsSoupName)
    }
    
    func deleteGlobalSyncs() {
        self.globalStore?.clearSoup(kSFSyncStateSyncsSoupName)
    }
    
    func createContacts(count: UInt,isLocal : Bool) -> [Dictionary <String,Any>] {
        var contacts:[Dictionary<String,Any>]  = [Dictionary<String,Any>]()
        var attributes  = [String:String]()
        attributes[TYPE] = CONTACT_TYPE
        
        for _ in 1...count {
            var contact: Dictionary<String,Any> = [String:Any]()
            let contactId = self.createLocalId()
            contact[FIRST_NAME] = "FC_\(contactId)"
            contact[LAST_NAME] = "LC_\(contactId)"
            contact[TITLE] = "TC_\(contactId)"
            contact[MOBILE_PHONE] = "9999999999"
            contact[HOME_PHONE] = "9999999999"
            contact[DESCRIPTION] = contactId
            contact[EMAIL] = contactId + "@" + "mymail.abc"
            contact[ATTRIBUTES] = attributes
            if isLocal {
                contact[ID] = contactId
                contact[kSyncTargetLocal] = true
                contact[kSyncTargetLocallyCreated] = true
                contact[kSyncTargetLocallyDeleted] = false
                contact[kSyncTargetLocallyUpdated] = false
            }
            contacts.append(contact)
        }
        return contacts
    }
   
    func createContactsLocally(count: UInt) -> Promise<[[String:Any]]> {
        let contacts:[Dictionary<String,Any>]  = createContacts(count: count,isLocal: true)
        return (self.store?.Promises.upsertEntries(entries: contacts, soupName: CONTACTS_SOUP))!
    }
    
    func dropContactsSoup() -> Promise<Void> {
        return (self.store?.Promises.removeSoup(soupName: CONTACTS_SOUP))!
    }
    
   func createContactsSoup() -> Promise<Bool> {
        let indexSpecs:[AnyObject]! = [
            SFSoupIndex(path: ID, indexType: kSoupIndexTypeString, columnName: nil)!,
            SFSoupIndex(path:FIRST_NAME, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:LAST_NAME, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:TITLE, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:MOBILE_PHONE, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:HOME_PHONE, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:EMAIL, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:DESCRIPTION, indexType:kSoupIndexTypeFullText, columnName:nil)!,
            SFSoupIndex(path:kSyncTargetLocal, indexType:kSoupIndexTypeString, columnName:nil)!,
            SFSoupIndex(path:kSyncTargetSyncId, indexType:kSoupIndexTypeInteger, columnName:nil)!
        ]
        return (self.store?.Promises.registerSoup(soupName: CONTACTS_SOUP, indexSpecs: indexSpecs))!
    }
    
    func fetchAllTestContactsFromServer() throws -> Promise<SFRestResponse> {
        guard let sfRestApi = SFRestAPI.sharedInstance(withUser: currentUser!) else {
            return Promise(.pending) { _ in
                throw TestError.InitializationError
            }
        }
        return sfRestApi.Promises
            .query(soql: "Select Id from Contact where FirstName LIKE 'FC_%'")
            .then { request in
                return sfRestApi.Promises.send(request: request)
        }
    }
    
    func fetchContactsFromServer(contactIds: [String]) throws -> Promise<SFRestResponse> {
        guard let sfRestApi = SFRestAPI.sharedInstance(withUser: currentUser!) else {
            return Promise(.pending) { _ in
                throw TestError.InitializationError
            }
        }
        let inString = contactIds.joined(separator: "','")
        return sfRestApi.Promises
            .query(soql: "Select \(contactFieldList.joined(separator: ",")) from Contact where Id in ('\(inString)')" )
            .then { request in
                return sfRestApi.Promises.send(request: request)
        }
    }
    
    func createSyncDownTargetFor(contactIds: [String]) -> SFSoqlSyncDownTarget {
        let inString = contactIds.joined(separator: "','")
        let soqlQuery = "Select \(contactFieldList.joined(separator: ",")) from Contact where Id in ('\(inString)')"
        let syncTarget = SFSoqlSyncDownTarget.newSyncTarget(soqlQuery)
        return syncTarget
    }
    
    func deleteContactsFromServer(contactIds : [String]) throws -> Promise<Void> {
        guard let sfRestApi = SFRestAPI.sharedInstance(withUser: currentUser!) else {
            return Promise(.pending) { _ in
                throw TestError.InitializationError
            }
        }
        var requests: [SFRestRequest] = []
        contactIds.forEach { id in
            requests.append(sfRestApi.requestForDelete(withObjectType: CONTACT_TYPE, objectId: id))
        }
        
        return sfRestApi.Promises
            .batch(requests: requests, haltOnError: false)
            .then { request -> Promise<SFRestResponse> in
                return sfRestApi.Promises.send(request: request)
            }.then { _ -> Promise<Void> in
                return Promise(value:())
        }
    }
    
    func deleteAllTestContactsFromServer() throws -> Promise<Void> {
        
        let querySpec = SFQuerySpec.Builder(soupName: CONTACTS_SOUP)
            .queryType(value: .range)
            .selectedPaths(value: [ID])
            .pageSize(value: UInt.max)
            .build()
        
        return
            (self.store?.Promises.query(querySpec: querySpec, pageIndex: 0)
                .then { result -> Promise<[String]> in
                    XCTAssertTrue(result.count>0)
                    var contactIds:[String] = []
                    result.forEach { record in
                        let values = record as! [String]
                        contactIds.append(values[0])
                    }
                    return Promise(value: contactIds)
                }
                .then { contactIds -> Promise<Void> in
                    XCTAssertTrue(contactIds.count>0)
                    return try self.deleteContactsFromServer(contactIds: contactIds)
                })!
    }
    
    func createContactsOnServer(noOfRecords: UInt) throws -> Promise<[String]> {
        guard let sfRestApi = SFRestAPI.sharedInstance(withUser: currentUser!) else {
            return Promise(.pending) { _ in
                throw TestError.InitializationError
            }
        }
        
        var requests:[SFRestRequest] = []
        
        let contacts = self.createContacts(count: noOfRecords,isLocal: false)
        
        contacts.forEach { contact in
            requests.append(sfRestApi.requestForCreate(withObjectType: CONTACT_TYPE, fields: contact))
        }
        
        return sfRestApi.Promises.batch(requests: requests, haltOnError: false)
                .then { request in
                    sfRestApi.Promises.send(request: request)
                }.then { response ->Promise<[String]> in
                    return Promise(value: self.getIdsFromBatchResults(response: response))
                }
    }
    
    func getIdsFromBatchResults(response: SFRestResponse) -> [String] {
        var contactIds: [String] = []
        let results = response.asJsonDictionary()["results"] as! [[String:Any]]
        results.forEach { resultEnvelope in
            let result = resultEnvelope["result"] as! [String:Any]
            let statusCode = resultEnvelope["statusCode"] as! Int
            XCTAssertNotNil(result)
            XCTAssertTrue(statusCode==201)
            XCTAssertNotNil(result["id"])
            contactIds.append(result["id"] as! String)
        }
        return contactIds
    }
    
    private func createLocalId() -> String {
        return String(format:"LC_%08d", arc4random_uniform(100000000))
    }
  
}

/*
 * Copyright (c) 2018-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided
 * that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the
 * following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
 * the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or
 * promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import { assert } from 'chai';
import { registerTest, testDone } from './react.force.test';
import { promiser }  from './react.force.util';
import { smartstore } from 'react-native-force';

// Promised based bridge functions for more readable tests
getDatabaseSize = promiser(smartstore.getDatabaseSize);
registerSoup = promiser(smartstore.registerSoup);
soupExists = promiser(smartstore.soupExists);
removeSoup = promiser(smartstore.removeSoup);
getSoupSpec = promiser(smartstore.getSoupSpec);
getSoupIndexSpecs = promiser(smartstore.getSoupIndexSpecs);
upsertSoupEntries = promiser(smartstore.upsertSoupEntries);
retrieveSoupEntries = promiser(smartstore.retrieveSoupEntries);
querySoup = promiser(smartstore.querySoup);
runSmartQuery = promiser(smartstore.runSmartQuery);
removeFromSoup = promiser(smartstore.removeFromSoup);
clearSoup = promiser(smartstore.clearSoup);
getAllStores = promiser(smartstore.getAllStores);
getAllGlobalStores = promiser(smartstore.getAllGlobalStores);
removeStore = promiser(smartstore.removeStore);

const storeConfig = {isGlobalStore:false};

testGetDatabaseSize = () => {
    getDatabaseSize(storeConfig)
        .then((result) => {
            assert.isNumber(result, 'Expected number');
            testDone();
        });
};

testRegisterExistsRemoveExists = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}, {path:'Id', type:'string'}];    
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return soupExists(storeConfig, soupName);
        })
        .then((result) => {
            assert.isTrue(result, 'Soup should exist');
            return removeSoup(storeConfig, soupName);
        })
        .then(() => {
            return soupExists(storeConfig, soupName);
        })
        .then((result) => {
            assert.isFalse(result, 'Soup should no longer exist');
            testDone();
        });
};

testGetSoupSpec = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}, {path:'Id', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return getSoupSpec(storeConfig, soupName);
        })
        .then((result) => {
            assert.deepEqual(result, {'name':soupName,'features':[]}, 'Wrong soup spec');
            testDone();
        });
};

testGetSoupIndexSpecs = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}, {path:'Id', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return getSoupIndexSpecs(storeConfig, soupName)
        })
        .then((result) => {
            assert.deepEqual(result, indexSpecs, 'Wrong index specs');
            testDone();
        });
};

testUpsertRetrieve = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return upsertSoupEntries(storeConfig, soupName, [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}]);
        })
        .then((result) => {
            assert.equal(3, result.length, 'Wrong number of entries');
            assert.equal('Aaa', result[0].Name);
            assert.equal('Bbb', result[1].Name);
            assert.equal('Ccc', result[2].Name);

            return retrieveSoupEntries(storeConfig, soupName, [result[0]._soupEntryId,result[2]._soupEntryId]);
        })
        .then((result) => {
            assert.equal(2, result.length, 'Wrong number of entries');
            assert.equal('Aaa', result[0].Name);
            assert.equal('Ccc', result[1].Name);
            testDone();
        });
};

testQuerySoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return upsertSoupEntries(storeConfig, soupName, [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}]);
        })
        .then((result) => {
            return querySoup(storeConfig, soupName, {queryType:'exact', indexPath:'Name', matchKey:'Bbb', order: 'ascending', pageSize:32});
        })
        .then((result) => {
            assert.equal(1, result.totalPages);
            assert.equal(1, result.totalPages);
            assert.isDefined(result.cursorId);
            assert.equal(0, result.currentPageIndex);
            assert.equal(32, result.pageSize);
            assert.equal(1, result.currentPageOrderedEntries.length);
            assert.equal('Bbb', result.currentPageOrderedEntries[0].Name);
            testDone();
        });
};

testSmartQuerySoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return upsertSoupEntries(storeConfig, soupName, [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}]);
        })
        .then((result) => {
            return runSmartQuery(storeConfig, {queryType:'smart', smartSql:'select {' + soupName + ':Name} from {' + soupName + '} where {' + soupName + ':Name} = "Ccc"', pageSize:32});
        })
        .then((result) => {
            assert.equal(1, result.totalPages);
            assert.equal(1, result.totalPages);
            assert.isDefined(result.cursorId);
            assert.equal(0, result.currentPageIndex);
            assert.equal(32, result.pageSize);
            assert.deepEqual([['Ccc']], result.currentPageOrderedEntries);
            testDone();
        });
};

testRemoveFromSoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return upsertSoupEntries(storeConfig, soupName, [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}]);
        })
        .then((result) => {
            return removeFromSoup(storeConfig, soupName, {queryType:'exact', indexPath:'Name', matchKey:'Bbb', order: 'ascending', pageSize:32});
        })
        .then(() => {
            return runSmartQuery(storeConfig, {queryType:'smart', smartSql:'select {' + soupName + ':Name} from {' + soupName + '} order by {' + soupName + ':Name}', pageSize:32});
        })
        .then((result) => {
            assert.deepEqual([['Aaa'], ['Ccc']], result.currentPageOrderedEntries);
            testDone();
        });
};

testClearSoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(storeConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return upsertSoupEntries(storeConfig, soupName, [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}]);
        })
        .then((result) => {
            return clearSoup(storeConfig, soupName);
        })
        .then(() => {
            return runSmartQuery(storeConfig, {queryType:'smart', smartSql:'select {' + soupName + ':Name} from {' + soupName + '} order by {' + soupName + ':Name}', pageSize:32});
        })
        .then((result) => {
            assert.deepEqual([], result.currentPageOrderedEntries);
            testDone();
        });
};

testGetAllStoresRemoveStore = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const storeName = 'store_' + uniq;
    const newStoreConfig = {isGlobalStore:false, storeName:storeName};
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(newStoreConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return getAllStores();
        })
        .then((result) => {
            assert.deepEqual([newStoreConfig], result);
            return removeStore(newStoreConfig);
        })
        .then((result) => {
            return getAllStores();
        })
        .then((result) => {
            assert.deepEqual([], result);
            testDone();
        });
};

testGetAllGlobalStoresRemoveStore = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const storeName = 'store_' + uniq;
    const newStoreConfig = {isGlobalStore:true, storeName:storeName};
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    registerSoup(newStoreConfig, soupName, indexSpecs)
        .then((result) => {
            assert.equal(result, soupName, 'Expected soupName');
            return getAllGlobalStores();
        })
        .then((result) => {
            assert.deepEqual([newStoreConfig], result);
            return removeStore(newStoreConfig);
        })
        .then((result) => {
            return getAllGlobalStores();
        })
        .then((result) => {
            assert.deepEqual([], result);
            testDone();
        });
};


registerTest(testGetDatabaseSize);
registerTest(testRegisterExistsRemoveExists);
registerTest(testGetSoupSpec);
registerTest(testGetSoupIndexSpecs);
registerTest(testUpsertRetrieve);
registerTest(testQuerySoup);
registerTest(testSmartQuerySoup);
registerTest(testRemoveFromSoup);
registerTest(testClearSoup);
registerTest(testGetAllStoresRemoveStore);
registerTest(testGetAllGlobalStoresRemoveStore);

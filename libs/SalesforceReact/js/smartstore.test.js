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
import { smartstore } from 'react-native-force';

const storeConfig = {isGlobalStore:false};

testGetDatabaseSize = () => {
    smartstore.getDatabaseSize(
        storeConfig,
        (result) => {
            assert.isNumber(result, 'Expected number');
            testDone();
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testRegisterExistsRemoveExists = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}, {path:'Id', type:'string'}];    
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.soupExists(
                storeConfig,
                soupName,
                (result) => {
                    assert.isTrue(result, 'Soup should exist');
                    smartstore.removeSoup(
                        storeConfig,
                        soupName,
                        () => {
                            smartstore.soupExists(
                                storeConfig,
                                soupName,
                                (result) => {
                                    assert.isFalse(result, 'Soup should no longer exist');
                                    testDone();
                                },
                                (error) => { throw error; }
                            );
                        },
                        (error) => { throw error; }
                    );
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testGetSoupSpec = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}, {path:'Id', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.getSoupSpec(
                storeConfig,
                soupName,
                (result) => {
                    assert.deepEqual(result, {'name':soupName,'features':[]}, 'Wrong soup spec');
                    testDone();
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testGetSoupIndexSpecs = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}, {path:'Id', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.getSoupIndexSpecs(
                storeConfig,
                soupName,
                (result) => {
                    assert.deepEqual(result, indexSpecs, 'Wrong index specs');
                    testDone();
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testUpsertRetrieve = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.upsertSoupEntries(
                storeConfig,
                soupName,
                [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}],
                (result) => {
                    assert.equal(3, result.length, 'Wrong number of entries');
                    assert.equal('Aaa', result[0].Name);
                    assert.equal('Bbb', result[1].Name);
                    assert.equal('Ccc', result[2].Name);

                    smartstore.retrieveSoupEntries(
                        storeConfig,
                        soupName,
                        [result[0]._soupEntryId,result[2]._soupEntryId],
                        (result) => {
                            assert.equal(2, result.length, 'Wrong number of entries');
                            assert.equal('Aaa', result[0].Name);
                            assert.equal('Ccc', result[1].Name);
                            testDone();
                        },
                        (error) => { throw error; }
                    );
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testQuerySoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.upsertSoupEntries(
                storeConfig,
                soupName,
                [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}],
                (result) => {
                    smartstore.querySoup(
                        storeConfig,
                        soupName,
                        {queryType:'exact', indexPath:'Name', matchKey:'Bbb', order: 'ascending', pageSize:32},
                        (result) => {
                            assert.equal(1, result.totalPages);
                            assert.equal(1, result.totalPages);
                            assert.isDefined(result.cursorId);
                            assert.equal(0, result.currentPageIndex);
                            assert.equal(32, result.pageSize);
                            assert.equal(1, result.currentPageOrderedEntries.length);
                            assert.equal('Bbb', result.currentPageOrderedEntries[0].Name);
                            testDone();
                        },
                        (error) => { throw error; }
                    );
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testSmartQuerySoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.upsertSoupEntries(
                storeConfig,
                soupName,
                [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}],
                (result) => {
                    smartstore.runSmartQuery(
                        storeConfig,
                        {
                            queryType:'smart',
                            smartSql:'select {' + soupName + ':Name} from {' + soupName + '} where {' + soupName + ':Name} = "Ccc"',
                            pageSize:32
                        },
                        (result) => {
                            assert.equal(1, result.totalPages);
                            assert.equal(1, result.totalPages);
                            assert.isDefined(result.cursorId);
                            assert.equal(0, result.currentPageIndex);
                            assert.equal(32, result.pageSize);
                            assert.deepEqual([['Ccc']], result.currentPageOrderedEntries);
                            testDone();
                        },
                        (error) => { throw error; }
                    );
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testRemoveFromSoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.upsertSoupEntries(
                storeConfig,
                soupName,
                [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}],
                (result) => {
                    smartstore.removeFromSoup(
                        storeConfig,
                        soupName,
                        {queryType:'exact', indexPath:'Name', matchKey:'Bbb', order: 'ascending', pageSize:32},
                        () => {
                            smartstore.runSmartQuery(
                                storeConfig,
                                {
                                    queryType:'smart',
                                    smartSql:'select {' + soupName + ':Name} from {' + soupName + '} order by {' + soupName + ':Name}',
                                    pageSize:32
                                },
                                (result) => {
                                    assert.deepEqual([['Aaa'], ['Ccc']], result.currentPageOrderedEntries);
                                    testDone();
                                },
                                (error) => { throw error; }
                            );
                        },
                        (error) => { throw error; }
                    );
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testClearSoup = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const soupName = 'soup_' + uniq;
    const indexSpecs = [{path:'Name', type:'string'}];
    smartstore.registerSoup(
        storeConfig,
        soupName,
        indexSpecs,
        (result) => {
            assert.equal(result, soupName, 'Expected soupName');
            smartstore.upsertSoupEntries(
                storeConfig,
                soupName,
                [{Name:'Aaa'}, {Name:'Bbb'}, {Name:'Ccc'}],
                (result) => {
                    smartstore.clearSoup(
                        storeConfig,
                        soupName,
                        () => {
                            smartstore.runSmartQuery(
                                storeConfig,
                                {
                                    queryType:'smart',
                                    smartSql:'select {' + soupName + ':Name} from {' + soupName + '} order by {' + soupName + ':Name}',
                                    pageSize:32
                                },
                                (result) => {
                                    assert.deepEqual([], result.currentPageOrderedEntries);
                                    testDone();
                                },
                                (error) => { throw error; }
                            );
                        },
                        (error) => { throw error; }
                    );
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
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

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
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS' AND ANY EXPRESS OR IMPLIED
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
import { net } from 'react-native-force';

const apiVersion = 'v42.0';

testGetApiVersion = () => {
    assert.equal(net.getApiVersion(), apiVersion);
};

testVersions = () => {
    net.versions(
        (response) => {
            assert.deepEqual(response[response.length-1], {'label':'Spring ’18','url':'/services/data/v42.0','version':'42.0'}, 'Wrong latest version');
            testDone();
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testResources = () => {
    net.resources(
        (response) => {
            assert.equal(response.connect, '/services/data/' + apiVersion + '/connect', 'Wrong url for connect resource');
            testDone();
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testDescribeGlobal = () => {
    net.describeGlobal(
        (response) => {
            assert.isArray(response.sobjects, 'Expected sobjects array');
            testDone();
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testMetaData = () => {
    net.metadata(
        'account',
        (response) => {
            assert.isObject(response.objectDescribe, 'Expected objectDescribe object');
            assert.isArray(response.recentItems, 'Expected recentItems array');
            testDone();
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testDescribe = () => {
    net.describe(
        'account',
        (response) => {
            assert.isFalse(response.custom, 'Expected custom to be false');
            assert.isArray(response.fields, 'Expected fields array');
            testDone();
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testDescribeLayout = () => {
    net.describe(
        'account',
        (response) => {
            const recordId = response.recordTypeInfos[0].recordTypeId;
            net.describeLayout(
                'account',
                recordId,
                (response) => {
                    assert.isArray(response.relatedLists, 'Expected relatedLists array');
                    testDone();
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );
    
    return false; // not done
};

testCreateRetrieve = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const firstName = 'First_' + uniq;
    const lastName = 'Last_' + uniq;
    
    net.create(
        'contact',
        {FirstName: firstName, LastName: lastName},
        (response) => {
            assert.isTrue(response.success, 'Create failed');
            const contactId = response.id;
            net.retrieve(
                'contact',
                contactId,
                'firstName,lastName',
                (response) => {
                    assert.equal(response.Id, contactId, 'Wrong id');
                    assert.equal(response.FirstName, firstName, 'Wrong first name');
                    assert.equal(response.LastName, lastName, 'Wrong last name');
                    testDone();
                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testUpsertUpdateRetrieve = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const firstName = 'First_' + uniq;
    const lastName = 'Last_' + uniq;
    const lastNameUpdated = lastName + '_updated';
    
    net.upsert(
        'contact',
        'Id',
        '',
        {FirstName: firstName, LastName: lastName},
        (response) => {
            assert.isTrue(response.success, 'Upsert failed');
            const contactId = response.id;
            net.update(
                'Contact',
                contactId,
                {LastName: lastNameUpdated},
                () => {
                    net.retrieve(
                        'contact',
                        contactId,
                        'firstName,lastName',
                        (response) => {
                            assert.equal(response.Id, contactId, 'Wrong id');
                            assert.equal(response.FirstName, firstName, 'Wrong first name');
                            assert.equal(response.LastName, lastNameUpdated, 'Wrong last name');
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

testCreateDelRetrieve = () => {
    const uniq = Math.floor(Math.random() * 1000000);
    const firstName = 'First_' + uniq;
    const lastName = 'Last_' + uniq;
    
    net.create(
        'contact',
        {FirstName: firstName, LastName: lastName},
        (response) => {
            assert.isTrue(response.success, 'Create failed');
            const contactId = response.id;
            net.del(
                'contact',
                contactId,
                () => {
                    net.retrieve(
                        'contact',
                        contactId,
                        'firstName,lastName',
                        (response) => {
                            assert.fail('Retrieve following delete should have 404ed');
                        },
                        (error) => {
                            assert.include(error.message, 'Code=404', 'Retrieve following delete should have 404ed');
                            testDone();
                        }
                    );

                },
                (error) => { throw error; }
            );
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testQuery = () => {
    net.query(
        'SELECT FirstName, LastName FROM Contact LIMIT 5',
        (response) => {
            assert.isArray(response.records, 'Expected records');
            assert.isTrue(response.done, 'Expected done to be true');
            assert.isNumber(response.totalSize, 'Expected totalSize');
            testDone();
        },
        (error) => { throw error; }
    );

    return false; // not done
};

testSearch = () => {
    net.search(
        'FIND {Joe} IN NAME FIELDS RETURNING Contact',
        (response) => {
            assert.isArray(response.searchRecords, 'Expected searchRecords');
            testDone();
        },
        (error) => { throw error; }
    );

    return false; // not done
};


registerTest(testGetApiVersion);
registerTest(testVersions);
registerTest(testResources);
registerTest(testDescribeGlobal);
registerTest(testMetaData);
registerTest(testDescribe);
registerTest(testDescribeLayout);
registerTest(testCreateRetrieve);
registerTest(testUpsertUpdateRetrieve);
registerTest(testCreateDelRetrieve);
registerTest(testQuery);
registerTest(testSearch);

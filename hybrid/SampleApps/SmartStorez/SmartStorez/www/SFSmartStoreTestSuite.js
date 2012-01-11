/*
 * Copyright (c) 2012, salesforce.com, inc.
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

/*
A test suite for SmartStore
This file assumes that qunit.js has been previously loaded, as well as SFUtility.js.
To display results you'll need to load qunit.css and SFUtility.css as well.
*/
if (typeof SmartStoreTestSuite === 'undefined') { 


var SmartStoreTestSuite = function () {
	this.allTests = [];
	this.stateOfTestByName = {};
	this.currentTestName = null;
	this.defaultSoupName = "myPeopleSoup";
	this.defaultSoupIndexes = [
                   {path:"Name",type:"string"},
                   {path:"Id",type:"string"}
                   ];
	this.currentSoup = null;
	
	this.IDLE_TEST_STATE = 'idle';
	this.RUNNING_TEST_STATE = 'running';
	this.FAIL_TEST_STATE = 'fail';
	this.SUCCESS_TEST_STATE = 'success';
	
	this.NUM_CURSOR_MANIPULATION_ENTRIES = 103;
};



SmartStoreTestSuite.prototype.startTests = function() {
	//collect a list of test methods by introspection
	var key, self = this;
	
	for ( key in self) {
		//we specifically don't check hasOwnProperty here, to grab proto methods
		var val = self[key];
		if (typeof val === 'function') {
			if (key.indexOf("test") === 0) {
				//logToConsole("should run: " + key); 
				this.allTests.push(key);
				this.stateOfTestByName[key] = this.IDLE_TEST_STATE;
			}
		}
	}
	
	
	navigator.smartstore.removeSoup(this.defaultSoupName);
	
	QUnit.init();
	QUnit.stop();//don't start running tests til they're all queued
	
	QUnit.module("SmartStore");
	
	
	this.allTests.forEach(function(methName){
		logToConsole("Queueing: " + methName);
		QUnit.asyncTest(methName, function() {
			logToConsole("Running " + methName);
			self.currentTestName = methName;
			self.stateOfTestByName[methName] = self.RUNNING_TEST_STATE;
			self[methName]();
		});
	});

	QUnit.start();//start qunit now that all tests are queued
	
};

SmartStoreTestSuite.prototype.setTestFailedByName = function(name,error) {
	logToConsole("test '" + name + "' failed with error: " + error);
	this.stateOfTestByName[name] = this.FAIL_TEST_STATE;
	//inform qunit that this test failed and unpause qunit
	QUnit.ok(false, name);
	QUnit.start();
};

SmartStoreTestSuite.prototype.setTestSuccessByName = function(name) {
	this.stateOfTestByName[name] = this.SUCCESS_TEST_STATE;
	logToConsole("test '" + name + "' succeeded");
	//inform qunit that this test passed and unpause qunit
	QUnit.ok(true, name);
	QUnit.start();
};


SmartStoreTestSuite.prototype.registerDefaultSoup = function(cb) {
	var self = this;
    navigator.smartstore.registerSoup(this.defaultSoupName, this.defaultSoupIndexes,
		function(soup) { 
			logToConsole("onSuccessRegSoup: " + soup);
			self.currentSoup = soup; 
			if (cb !== null) {
				 cb(soup);
			}
		}, 
		function(param) { 
			logToConsole("onErrorRegSoup: " + param);
			if (cb !== null)  {
				cb(null);
			}
		}
      );
};

SmartStoreTestSuite.prototype.stuffTestSoup = function(cb) {
	//logToConsole("stuffTestSoup " + (typeof cb));
    
	var myEntry1 = { Name: "Todd Stellanova", Id: "00300A",  attributes:{type:"Contact"} };
    var myEntry2 = { Name: "Pro Bono Bonobo",  Id: "00300B", attributes:{type:"Contact"}  };
    var myEntry3 = { Name: "Robot", Id: "00300C", attributes:{type:"Contact"}  };
    var entries = [myEntry1,myEntry2,myEntry3];

	this.addEntriesToTestSoup(entries,cb);
};


SmartStoreTestSuite.prototype.addEntriesToTestSoup = function(entries,cb) {

    navigator.smartstore.upsertSoupEntries(this.defaultSoupName,entries,
		function(param) {
		    logToConsole("onSuccessUpsert: " + param);
			cb(param);
		},
		function(param) {
		    logToConsole("onErrorUpsert: " + param);
			cb(null);
		}
	);
};

SmartStoreTestSuite.prototype.addGeneratedEntriesToTestSoup = function(nEntries, cb) {
	logToConsole("addGeneratedEntriesToTestSoup " + nEntries);
 
	var entries = [];
	for (var i = 0; i < nEntries; i++) {
		var myEntry = { Name: "Todd Stellanova" + i, Id: "00300" + i,  attributes:{type:"Contact"} };
		entries.push(myEntry);
	}
	
	this.addEntriesToTestSoup(entries,cb);
	
};


/*
TEST registerSoup
*/
SmartStoreTestSuite.prototype.testRegisterSoup = function() {
	var self = this;
	this.registerDefaultSoup(function(soup) {
		logToConsole("registerDefaultSoup done: " + soup);
		if (soup === null) {
			self.setTestFailedByName("testRegisterSoup","null soup returned");
		} else {
			self.setTestSuccessByName("testRegisterSoup");
		}
	});
};

/* 
TEST removeSoup
*/
SmartStoreTestSuite.prototype.testRemoveSoup = function() {
	var self = this;
	navigator.smartstore.removeSoup(this.defaultSoupName,
		function(param) { 
			self.setTestSuccessByName("testRemoveSoup");
		}, 
		function(param) { 
			self.setTestFailedByName("testRemoveSoup",param);
		}
      );
};


/* 
TEST upsertSoupEntries
*/
SmartStoreTestSuite.prototype.testUpsertSoupEntries = function()  {
	var self = this;
	navigator.smartstore.removeSoup(this.defaultSoupName);
    this.registerDefaultSoup(null);
	this.addGeneratedEntriesToTestSoup(7,function(cursor) {
			self.continueUpsertSoupEntries(cursor);
		});
};

SmartStoreTestSuite.prototype.continueUpsertSoupEntries = function(cursor) {
	var self = this;	
	QUnit.equal(cursor.totalPages,1,"totalPages correct");
	QUnit.equal(cursor.currentPageOrderedEntries.length, 7);
	//upsert another batch
	this.addGeneratedEntriesToTestSoup(12,function(nextCursor) {
			self.continueUpsertSoupEntries2(nextCursor);
		});
};
 
SmartStoreTestSuite.prototype.continueUpsertSoupEntries2 = function(cursor)  {
	QUnit.equal(cursor.totalPages,2,"totalPages correct");
	QUnit.equal(cursor.currentPageOrderedEntries.length, cursor.pageSize);
	
	this.setTestSuccessByName("testUpsertSoupEntries");
}; 

/*
TEST retrieveSoupEntry
*/
SmartStoreTestSuite.prototype.testRetrieveSoupEntry = function()  {
	var self = this; 
    
	navigator.smartstore.removeSoup(this.defaultSoupName);
	this.registerDefaultSoup(null);
	this.stuffTestSoup(function(cursor) {
		self.continueRetrieveSoupEntry(cursor);
	});	
};

SmartStoreTestSuite.prototype.continueRetrieveSoupEntry = function(cursor)  {
	var self = this; 
	var originalEntry = cursor.currentPageOrderedEntries[0];
	var soupEntryId = originalEntry._soupEntryId;
	
	navigator.smartstore.retrieveSoupEntry(this.defaultSoupName,soupEntryId,
		function(entry) {
			QUnit.equal(soupEntryId,entry._soupEntryId,"soupEntryIds match");
			self.setTestSuccessByName("testRetrieveSoupEntry");
		},
		function(param) { 
			logToConsole("onErrorRetrieveEntry: " + param);
			self.setTestFailedByName("testRetrieveSoupEntry",param);
		}
	);
};




/*
TEST removeFromSoup
*/
SmartStoreTestSuite.prototype.testRemoveFromSoup = function()  {
	var self = this; 
    
	navigator.smartstore.removeSoup(this.defaultSoupName);
	this.registerDefaultSoup(null);
	this.stuffTestSoup(function(cursor) {
		self.continueRemoveFromSoup(cursor);
	});

};

SmartStoreTestSuite.prototype.continueRemoveFromSoup = function(cursor) {
	var self = this,  soupEntryIds = [];

	var nEntries = cursor.currentPageOrderedEntries.length;
	QUnit.equal(nEntries,3,"currentPageOrderedEntries correct");

	for (var i = cursor.currentPageOrderedEntries.length - 1; i >= 0; i--) {
		var entry = cursor.currentPageOrderedEntries[i];
		soupEntryIds.push(entry._soupEntryId);
	}
	
	navigator.smartstore.removeFromSoup(this.defaultSoupName, soupEntryIds,
		function(param) { 
			self.continueRemoveFromSoup2(param);
		}, 
		function(param) { 
			self.setTestFailedByName("testRemoveFromSoup",param);
		}
	);
};

SmartStoreTestSuite.prototype.continueRemoveFromSoup2 = function(status) {
	var self = this,  querySpec = new SoupQuerySpec("Name",null);
	QUnit.equal(status,"OK","removeFromSoup OK");

	navigator.smartstore.querySoup(this.defaultSoupName,querySpec,
		function(cursor) {
			var nEntries = cursor.currentPageOrderedEntries.length;
			QUnit.equal(nEntries,0,"currentPageOrderedEntries correct");
			self.setTestSuccessByName("testRemoveFromSoup");
		},
		function(param) { 
			logToConsole("onErrorQuerySoup: " + param);
			self.setTestFailedByName("testRemoveFromSoup",param);
		}
	);
};


/* 
TEST querySoup
*/
SmartStoreTestSuite.prototype.testQuerySoup = function()  {
	var self = this;
	this.stuffTestSoup(function(cursor) {
		self.continueQuerySoup(cursor);
	});
};

SmartStoreTestSuite.prototype.continueQuerySoup = function(cursor) {
	var self = this;
	QUnit.notEqual(cursor,null,"stuffTestSoup OK");
	
    var querySpec = new SoupQuerySpec("Name","Robot");
    querySpec.pageSize = 25;
    navigator.smartstore.querySoup(this.defaultSoupName,querySpec,
		function(cursor) {
			QUnit.equal(cursor.totalPages,1,"totalPages correct");
			var nEntries = cursor.currentPageOrderedEntries.length;
			QUnit.equal(nEntries,1,"currentPageOrderedEntries correct");
			self.setTestSuccessByName("testSmartStoreQuerySoup");
		},
		function(param) { 
			logToConsole("onErrorQuerySoup: " + param);
			self.setTestFailedByName("testSmartStoreQuerySoup",param);
		}
	);

};




/*
TEST moveCursorToNextPage
*/
SmartStoreTestSuite.prototype.testManipulateCursor = function()  {
	var self = this;
	navigator.smartstore.removeSoup(this.defaultSoupName);
	this.registerDefaultSoup(null);
	this.addGeneratedEntriesToTestSoup(self.NUM_CURSOR_MANIPULATION_ENTRIES,function(cursor) {
		self.continueManipulateCursor(cursor);
	});
};


SmartStoreTestSuite.prototype.continueManipulateCursor = function(cursor) {
	var self = this;
	QUnit.notEqual(cursor,null,"addGeneratedEntriesToTestSoup OK");
			
    var querySpec = new SoupQuerySpec("Name",null);

    navigator.smartstore.querySoup(this.defaultSoupName,querySpec,
		function(cursor) {
			QUnit.equal(cursor.currentPageIndex, 0,"currentPageIndex correct");
			QUnit.equal(cursor.pageSize,10,"pageSize correct");
			
			var nEntries = cursor.currentPageOrderedEntries.length;
			QUnit.equal(nEntries,cursor.pageSize,"nEntries matches pageSize");
						
			self.forwardCursorToEnd(cursor);
		},
		function(param) { 
			logToConsole("onErrorQuerySoup: " + param);
			self.setTestFailedByName("testManipulateCursor",param);
		}
	);

};

/*
Page through the cursor til we reach the end.
Used by testManipulateCursor
*/
SmartStoreTestSuite.prototype.forwardCursorToEnd = function(cursor) {
	var self = this;
	
	navigator.smartstore.moveCursorToNextPage(cursor,
		function(nextCursor) {
			var pageCount = nextCursor.currentPageIndex + 1;
			var nEntries = nextCursor.currentPageOrderedEntries.length;
			
			if (pageCount < nextCursor.totalPages) {
				logToConsole("pageCount:" + pageCount + " of " + nextCursor.totalPages);
				QUnit.equal(nEntries,nextCursor.pageSize,"nEntries matches pageSize [" + nextCursor.currentPageIndex + "]" );
				
				self.forwardCursorToEnd(nextCursor);
			} else {
				var expectedCurEntries = nextCursor.pageSize;
				var remainder = self.NUM_CURSOR_MANIPULATION_ENTRIES % nextCursor.pageSize;
				if (remainder > 0) {
					expectedCurEntries = remainder;
					logToConsole("remainder: " + remainder);
				}
				
				QUnit.equal(nextCursor.currentPageIndex,nextCursor.totalPages-1,"final pageIndex correct");
				QUnit.equal(nEntries,expectedCurEntries,"last page nEntries matches");
				
				self.setTestSuccessByName("testManipulateCursor");
			}
		},
		function(param) {
			logToConsole("onErrorNextPage: " + param);
			self.setTestFailedByName("testManipulateCursor",param);
		}
	);
};






}


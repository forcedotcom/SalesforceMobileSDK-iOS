
/*
A test suite for SmartStore

This file assumes that QUnit has been previously loaded, as well as SFUtility
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
	
	// QUnit.module("SmartStore", {
	//   setup: function() {
	//     QUnit.ok(true, "once extra assert before each test");
	//   },
	//   teardown: function() {
	// 	QUnit.ok(true, "and one extra assert after each test");
	//   }
	// });
	
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

SmartStoreTestSuite.prototype.testRemoveFromSoup = function()  {
	var self = this; 
    
	navigator.smartstore.removeSoup(this.defaultSoupName);
	this.registerDefaultSoup(null);
	this.stuffTestSoup(function(cursor) {
		self.continueRemoveSoupEntries(cursor);
	});

};

SmartStoreTestSuite.prototype.continueRemoveSoupEntries = function(cursor) {
	var self = this,  soupEntryIds = [];

	var nEntries = cursor.currentPageOrderedEntries.length;
	QUnit.equal(nEntries,3,"currentPageOrderedEntries correct");

	for (var i = cursor.currentPageOrderedEntries.length - 1; i >= 0; i--) {
		var entry = cursor.currentPageOrderedEntries[i];
		soupEntryIds.push(entry._soupEntryId);
	}
	
	navigator.smartstore.removeFromSoup(this.defaultSoupName, soupEntryIds,
		function(param) { 
			self.continueRemoveSoupEntries2(param);
		}, 
		function(param) { 
			self.setTestFailedByName("testRemoveFromSoup",param);
		}
	);
};

SmartStoreTestSuite.prototype.continueRemoveSoupEntries2 = function(status) {
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

}


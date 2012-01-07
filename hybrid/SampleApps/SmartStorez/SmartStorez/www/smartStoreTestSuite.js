
if (typeof SmartStoreTestSuite === 'undefined') { 


var SmartStoreTestSuite = function () {
	this.allTests = {};
	this.stateOfTestByName = {};
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
};



SmartStoreTestSuite.prototype.startTests = function() {
	//collect a list of test methods by introspection
	var self = this;
	for (var key in self) {
		//we specifically don't check hasOwnProperty here, to grab proto methods
		var val = self[key];
		if (typeof val === 'function') {
			if (key.indexOf("test") === 0) {
				logToConsole("should run: " + key); 
				this.allTests[key] = val;
				this.stateOfTestByName[key] = this.IDLE_TEST_STATE;
			}
		}
	}
		
	QUnit.stop();//don't start running tests til they're all queued?
	for (var methName in this.allTests) {
		this.stateOfTestByName[methName] = this.RUNNING_TEST_STATE;
		
		//call out to qunit
		QUnit.asyncTest(methName, function() {
			logToConsole("calling " + methName );
			self[methName]();
		});
		
	}
	QUnit.start();
	
};

SmartStoreTestSuite.prototype.setTestFailedByName = function(name,error) {
	logToConsole("test '" + name + "' failed with error: " + error);
	this.stateOfTestByName[name] = this.FAIL_TEST_STATE;
	
	QUnit.ok(false, name);
	QUnit.start();
};

SmartStoreTestSuite.prototype.setTestSuccessByName = function(name) {
	this.stateOfTestByName[name] = this.SUCCESS_TEST_STATE;
	logToConsole("test '" + name + "' succeeded");
	
	QUnit.ok(true, name);
	QUnit.start();
};


SmartStoreTestSuite.prototype.registerDefaultSoup = function(cb) {
	var self = this;
    navigator.smartstore.registerSoup(this.defaultSoupName, this.defaultSoupIndexes,
		function(soup) { 
			logToConsole("onSuccessRegSoup: " + soup);
			self.currentSoup = soup; 
			cb(soup);
		}, 
		function(param) { 
			logToConsole("onErrorRegSoup: " + param);
			cb(null);
		}
      );
};

SmartStoreTestSuite.prototype.stuffTestSoup = function(cb) {
	logToConsole("stuffTestSoup " + (typeof cb));
    
	var myEntry1 = { Name: "Todd Stellanova", Id: "00300A",  attributes:{type:"Contact"} };
    var myEntry2 = { Name: "Pro Bono Bonobo",  Id: "00300B", attributes:{type:"Contact"}  };
    var myEntry3 = { Name: "Robot", Id: "00300C", attributes:{type:"Contact"}  };

    var entries = [myEntry1,myEntry2,myEntry3];
    navigator.smartstore.upsertSoupEntries(this.defaultSoupName,entries,
		function(cursor) {
		    logToConsole("onSuccessUpsert: " + cursor);
			cb(cursor);
		},
		function(param) {
		    logToConsole("onErrorUpsert: " + param);
			cb(null);
		}
	);

};


SmartStoreTestSuite.prototype.testSmartStoreQuerySoup = function()  {
	var self = this;
	this.stuffTestSoup(function(cursor) {
		self.continueSmartStoreQuerySoup(cursor);
	});
};


SmartStoreTestSuite.prototype.continueSmartStoreQuerySoup = function(cursor) {
	if (cursor !== null) {
	    var querySpec = new SoupQuerySpec("Name","Robot");
	    querySpec.pageSize = 25;
       var self = this;
	    navigator.smartstore.querySoup(this.defaultSoupName,querySpec,
			function(cursor) {
			    logToConsole("onSuccessQuerySoup totalPages: " + cursor.totalPages);
				self.setTestSuccessByName("testSmartStoreQuerySoup");
			},
			function(param) { 
				logToConsole("onErrorQuerySoup: " + param);
				self.setTestFailedByName("testSmartStoreQuerySoup",param);
			}
		);
	} else {
		this.setTestFailedByName("testSmartStoreQuerySoup","stuffTestSoup failed");
	}
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


}
'use strict';

var { SFSmartStoreReactBridge } = require('NativeModules');

module.exports = {
    
    showInspector: function() {
        SFSmartStoreReactBridge.showInspector({}, 
                                              function() {console.log("showInspector succeeded");},
                                              function() {console.log("showInspector failed");}
                                             );
    }
}

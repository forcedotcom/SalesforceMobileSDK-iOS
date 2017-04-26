cordova.define('cordova/plugin_list', function(require, exports, module) {
module.exports = [
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.oauth.js",
        "id": "com.salesforce.plugin.oauth"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.sfaccountmanager.js",
        "id": "com.salesforce.plugin.sfaccountmanager"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.sdkinfo.js",
        "id": "com.salesforce.plugin.sdkinfo"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.smartstore.js",
        "id": "com.salesforce.plugin.smartstore",
        "clobbers": [
            "navigator.smartstore"
        ]
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.smartstore.client.js",
        "id": "com.salesforce.plugin.smartstore.client",
        "clobbers": [
            "navigator.smartstoreClient"
        ]
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.smartsync.js",
        "id": "com.salesforce.plugin.smartsync",
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.util.bootstrap.js",
        "id": "com.salesforce.util.bootstrap"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.util.event.js",
        "id": "com.salesforce.util.event"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.util.exec.js",
        "id": "com.salesforce.util.exec"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.util.promiser.js",
        "id": "com.salesforce.util.promiser"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.util.logger.js",
        "id": "com.salesforce.util.logger"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.util.push.js",
        "id": "com.salesforce.util.push"
    },
    {
        "file": "plugins/org.apache.cordova.console/www/console-via-logger.js",
        "id": "org.apache.cordova.console.console",
        "clobbers": [
            "console"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.console/www/logger.js",
        "id": "org.apache.cordova.console.logger",
        "clobbers": [
            "cordova.logger"
        ]
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.network.js",
        "id": "com.salesforce.plugin.network"
    }
];
module.exports.metadata = 
// TOP OF METADATA
{
    "com.salesforce": "5.2.0",
    "org.apache.cordova.console": "0.2.11"
}
// BOTTOM OF METADATA
});

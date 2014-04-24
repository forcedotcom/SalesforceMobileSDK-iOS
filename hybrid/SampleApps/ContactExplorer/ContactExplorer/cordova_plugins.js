cordova.define('cordova/plugin_list', function(require, exports, module) {
module.exports = [
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.oauth.js",
        "id": "com.salesforce.plugin.oauth"
    },
    {
        "file": "plugins/com.salesforce/com.salesforce.plugin.sfaccountmanager.js",
        "id": "com.salesforce.plugin.sfacccountmanager"
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
        "file": "plugins/com.salesforce/com.salesforce.util.logger.js",
        "id": "com.salesforce.util.logger"
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/contacts.js",
        "id": "org.apache.cordova.contacts.contacts",
        "clobbers": [
            "navigator.contacts"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/Contact.js",
        "id": "org.apache.cordova.contacts.Contact",
        "clobbers": [
            "Contact"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/ContactAddress.js",
        "id": "org.apache.cordova.contacts.ContactAddress",
        "clobbers": [
            "ContactAddress"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/ContactError.js",
        "id": "org.apache.cordova.contacts.ContactError",
        "clobbers": [
            "ContactError"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/ContactField.js",
        "id": "org.apache.cordova.contacts.ContactField",
        "clobbers": [
            "ContactField"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/ContactFindOptions.js",
        "id": "org.apache.cordova.contacts.ContactFindOptions",
        "clobbers": [
            "ContactFindOptions"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/ContactName.js",
        "id": "org.apache.cordova.contacts.ContactName",
        "clobbers": [
            "ContactName"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/www/ContactOrganization.js",
        "id": "org.apache.cordova.contacts.ContactOrganization",
        "clobbers": [
            "ContactOrganization"
        ]
    },
    {
        "file": "plugins/org.apache.cordova.contacts/src/windows8/ContactProxy.js",
        "id": "org.apache.cordova.contacts.ContactProxy",
        "merges": [
            ""
        ]
    }
];
module.exports.metadata = 
// TOP OF METADATA
{
    "com.salesforce": "2.3.0",
    "org.apache.cordova.contacts": "0.2.9"
}
// BOTTOM OF METADATA
});


var SalesforceOAuthPlugin = {
    getLoginHost: function(success, fail) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth", "getLoginHost", []);
    }
};
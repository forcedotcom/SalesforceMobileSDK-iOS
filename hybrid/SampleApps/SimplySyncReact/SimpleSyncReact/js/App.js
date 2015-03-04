'use strict';

var smartsync = require('./SmartSync');
var smartstore = require('./SmartStore');
var oauth = require('./OAuth');
var React = require('react-native/addons');
var {
  AppRegistry,
  NavigatorIOS,
  StyleSheet,
} = React;

var SearchScreen = require('./SearchScreen');

var App = React.createClass({
  render: function() {
    return (
      <NavigatorIOS
        style={styles.container}
        initialRoute={{
          title: 'Users',
          component: SearchScreen,
        }}
      />
    );
  }
});

var styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
});


AppRegistry.registerComponent('App', () => App);

// Misc initialization
oauth.getAccessToken();

smartstore.registerSoup("users", 
                        [ {path:"Id", type:"string"}, 
                          {path:"FirstName", type:"string"}, 
                          {path:"LastName", type:"string"}, 
                          {path:"__local__", type:"string"} ]);

var fieldlist = ["Id", "FirstName", "LastName", "Title", "CompanyName", "Email", "MobilePhone","City", "SmallPhotoUrl", "FullPhotoUrl"];
var target = {type:"soql", query:"SELECT " + fieldlist.join(",") + " FROM User WHERE CompanyName = 'salesforce.com' LIMIT 1000"};
smartsync.syncDown(target, "users", {mergeMode:smartsync.MERGE_MODE.OVERWRITE});


module.exports = App;

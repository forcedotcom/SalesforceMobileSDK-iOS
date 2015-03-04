'use strict';

var smartstore = require('./SmartStore');
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

// Wrong place?
smartstore.registerSoup("users", [ {path:"Id", type:"string"}, {path:"FirstName", type:"string"}, {path:"LastName", type:"string"}, {path:"__local__", type:"string"} ],  function() {}, function() {});

module.exports = App;

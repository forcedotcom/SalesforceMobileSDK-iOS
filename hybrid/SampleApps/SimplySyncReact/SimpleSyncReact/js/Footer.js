'use strict';

var React = require('react-native/addons');
var SmartStore = require('./SmartStore');
var SmartSync = require('./SmartSync');

var {
  Text,
  View,
  TouchableHighlight,
  StyleSheet
} = React;

var style = StyleSheet.create({
  row: {
    height: 50, 
    alignItems: 'center'
  }
});

var fieldlist = ["Id", "FirstName", "LastName", "Title", "CompanyName", "Email", "MobilePhone","City"];

var syncDown = function() {
    var target = {type:"soql", query:"SELECT " + fieldlist.join(",") + " FROM User LIMIT 10000"};
    SmartSync.syncDown(target, "users", {mergeMode:SmartSync.MERGE_MODE.OVERWRITE}, function() {},  function() {});
};

var showInspector = function() {
    SmartStore.showInspector(function() {},  function() {});
};

module.exports = React.createClass({

  render: function() {
    return (
      <View>
        <TouchableHighlight onPress={() => syncDown()}>
          <View style={style.row}>
            <Text>Sync down</Text>
          </View>
        </TouchableHighlight>

        <TouchableHighlight onPress={() => showInspector()}>
          <View style={style.row}>
            <Text>DB</Text>
          </View>
        </TouchableHighlight>
      </View>
    );
  }

});

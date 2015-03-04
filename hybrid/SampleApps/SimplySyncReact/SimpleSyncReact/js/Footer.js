'use strict';

var React = require('react-native/addons');
var smartstore = require('./SmartStore');

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

var showInspector = function() {
    smarstore.showInspector();
};

module.exports = React.createClass({

  render: function() {
    return (
      <View>
        <TouchableHighlight onPress={() => showInspector()}>
          <View style={style.row}>
            <Text>DB</Text>
          </View>
        </TouchableHighlight>
      </View>
    );
  }

});

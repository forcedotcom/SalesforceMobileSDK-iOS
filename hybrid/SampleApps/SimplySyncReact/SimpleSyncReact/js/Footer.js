'use strict';

var React = require('react-native/addons');
var SmartStore = require('./SmartStore');
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

module.exports = React.createClass({

  render: function() {
    return (
      <View>
        <TouchableHighlight onPress={() => SmartStore.showInspector()}>
          <View style={style.row}>
            <Text>DB</Text>
          </View>
        </TouchableHighlight>
      </View>
    );
  }

});

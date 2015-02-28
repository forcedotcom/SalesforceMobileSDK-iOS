'use strict';

var React = require('react-native/addons');

var {
  Bundler,
  NavigatorIOS,
  Text,
  TouchableHighlight,
  View,
} = React;

var App = React.createClass({
  render () {
    return (
      <View style={{flex:1}}>
        <Text>Hello World</Text>
      </View>
    );
  }
});


Bundler.registerComponent('App', () => App);

module.exports = App;

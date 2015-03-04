'use strict';

var React = require('react-native');
var {
  ExpandingText,
  PixelRatio,
  ScrollView,
  StyleSheet,
  Text,
  View,
} = React;


var UserScreen = React.createClass({
  render: function() {
    return (
      <ScrollView contentContainerStyle={styles.contentContainer}>
        <View style={styles.mainSection}>
          <View style={styles.rightPane}>
            <Text style={styles.name}>{this.props.user.FirstName} {this.props.user.LastName}</Text>
            <Text>{this.props.user.Title}</Text>
          </View>
        </View>
      </ScrollView>
    );
  },
});

var styles = StyleSheet.create({
  contentContainer: {
    padding: 10,
  },
  rightPane: {
    justifyContent: 'space-between',
    flex: 1,
  },
  name: {
    flex: 1,
    fontSize: 16,
    fontWeight: 'bold',
  },
  mainSection: {
    flexDirection: 'row',
  },
  separator: {
    backgroundColor: 'rgba(0, 0, 0, 0.1)',
    height: 1 / PixelRatio.get(),
    marginVertical: 10,
  }
});

module.exports = UserScreen;

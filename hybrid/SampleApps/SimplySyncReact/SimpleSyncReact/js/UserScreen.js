'use strict';

var oauth = require('./OAuth');
var React = require('react-native');
var {
    ExpandingText,
    Image,
    PixelRatio,
    ScrollView,
    StyleSheet,
    Text,
    View,
} = React;
var OAuth = require('./OAuth');

var UserScreen = React.createClass({
    render: function() {
        var imgSrc = { uri: this.props.user.FullPhotoUrl + "?oauth_token=" + oauth.getAccessToken() };
        return (
                <ScrollView contentContainerStyle={styles.contentContainer}>
                  <View style={styles.mainSection}>
                    <Image
                       source={imgSrc}
                       style={styles.detailsImage}
                       />
                    <View style={styles.rightPane}>
                      <Text style={styles.name}>{this.props.user.FirstName} {this.props.user.LastName}</Text>
                      <Text>{this.props.user.Title} @ {this.props.user.CompanyName}</Text>
                      <Text>{this.props.user.Email}</Text>
                      <Text>{this.props.user.MobilePhone}</Text>
                      <Text>{this.props.user.City}</Text>
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
    detailsImage: {
        width: 134,
        height: 200,
        backgroundColor: '#eaeaea',
        marginRight: 10,
    },
    separator: {
        backgroundColor: 'rgba(0, 0, 0, 0.1)',
        height: 1 / PixelRatio.get(),
        marginVertical: 10,
    }
});

module.exports = UserScreen;

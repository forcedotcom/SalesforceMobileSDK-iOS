'use strict';

var oauth = require('./OAuth');
var React = require('react-native');
var {
    Image,
    PixelRatio,
    StyleSheet,
    Text,
    TouchableHighlight,
    View
} = React;

var UserCell = React.createClass({
    render: function() {
        var imgSrc = { uri: this.props.user.FullPhotoUrl + "?oauth_token=" + oauth.getAccessToken() };
        return (
                <View>
                  <TouchableHighlight onPress={this.props.onSelect}>
                    <View style={styles.row}>
                      <Image
                         source={imgSrc}
                         style={styles.cellImage}
                         />
                      <View style={styles.textContainer}>
                        <Text style={styles.name} numberOfLines={2}>
                          {this.props.user.FirstName} {this.props.user.LastName}
                        </Text>
                        <Text style={styles.title} numberOfLines={1}>
                          {this.props.user.Title} @ {this.props.user.CompanyName}
                        </Text>
                      </View>
                    </View>
                  </TouchableHighlight>
                  <View style={styles.cellBorder} />
                </View>
               );
    }
});

var styles = StyleSheet.create({
    textContainer: {
        flex: 1,
    },
    name: {
        flex: 1,
        fontSize: 16,
        fontWeight: 'bold',
        marginBottom: 2,
    },
    title: {
        color: '#999999',
        fontSize: 12,
    },
    row: {
        alignItems: 'center',
        backgroundColor: 'white',
        flexDirection: 'row',
        padding: 5,
    },
    cellImage: {
        backgroundColor: '#dddddd',
        height: 93,
        marginRight: 10,
        width: 70,
    },
    cellBorder: {
        backgroundColor: 'rgba(0, 0, 0, 0.1)',
        // Trick to get the thinest line the device can display
        height: 1 / PixelRatio.get(),
        marginLeft: 4,
    },
});

module.exports = UserCell;

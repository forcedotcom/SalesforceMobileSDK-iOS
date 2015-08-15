'use strict';

var React = require('react-native');
var {
    AppRegistry,
    StyleSheet,
    Text,
    View,
    ListView,
    PixelRatio,
    NavigatorIOS
} = React;
var smartstore = require('./react.force.smartstore.js');
var smartsync = require('./react.force.smartsync.js');

var App = React.createClass({
    render: function() {
        return (
            <NavigatorIOS
                style={styles.container}
                initialRoute={{
                    title: 'Mobile SDK Sample App',
                    component: UserList,
                }}
            />
        );
    }
});

var UserList = React.createClass({
    getInitialState: function() {
      var ds = new ListView.DataSource({rowHasChanged: (r1, r2) => r1 !== r2});
      return {
          dataSource: ds.cloneWithRows([]),
      };
    },
    
    componentDidMount: function() {
        var that = this;
        smartstore.registerSoup(false,
                                "users", 
                                [ {path:"Id", type:"string"}, 
                                  {path:"Name", type:"string"}, 
                                  {path:"__local__", type:"string"} ],
                                function() {
                                    that.runSync();
                                });
    },

    runSync: function() {
        var that = this;
        var fieldlist = ["Id", "Name"];
        var target = {type:"soql", query:"SELECT " + fieldlist.join(",") + " FROM User LIMIT 10"};
        smartsync.syncDown(false, target, "users", {mergeMode:smartsync.MERGE_MODE.OVERWRITE}, function(result) {
            smartstore.querySoup(false,
                                 "users",
                                 smartstore.buildAllQuerySpec("Name"),                             
                                 function(cursor) {
                                     that.handleData(cursor);
                                 });
        });
    },

    handleData: function(cursor) {
        var data = [];
        for (var i in cursor.currentPageOrderedEntries) {
            data.push(cursor.currentPageOrderedEntries[i]["Name"]);
        }

        this.setState({
            dataSource: this.getDataSource(data),
        });
    },

    getDataSource: function(users: Array<any>): ListViewDataSource {
        return this.state.dataSource.cloneWithRows(users);
    },

    render: function() {
        return (
            <ListView
              dataSource={this.state.dataSource}
              renderRow={this.renderRow} />
      );
    },

    renderRow: function(rowData: Object) {
        return (
                <View>
                    <View style={styles.row}>
                      <Text numberOfLines={1}>
                       {rowData}
                      </Text>
                    </View>
                    <View style={styles.cellBorder} />
                </View>
        );
    }
});

var styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: 'white',
    },
    header: {
        height: 50,
        alignItems:'center'
    },
    row: {
        flex: 1,
        alignItems: 'center',
        backgroundColor: 'white',
        flexDirection: 'row',
        padding: 12,
    },
    cellBorder: {
        backgroundColor: 'rgba(0, 0, 0, 0.1)',
        // Trick to get the thinest line the device can display
        height: 1 / PixelRatio.get(),
        marginLeft: 4,
    },
});


React.AppRegistry.registerComponent('__ReactNativeTemplateAppName__', () => App);

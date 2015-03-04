'use strict';

var React = require('react-native');
var {
    ListView,
    ListViewDataSource,
    ScrollView,
    ActivityIndicatorIOS,
    StyleSheet,
    Text,
    TextInput,
    TimerMixin,
    View,
} = React;

var smartstore = require('./SmartStore');
var Footer = require('./Footer');
var UserCell = require('./UserCell');
var UserScreen = require('./UserScreen');

var queryToLoading = {};
var queryToCursor = {};
var queryToData = {};

var SearchScreen = React.createClass({
    mixins: [TimerMixin],

    getInitialState: function() {
        return {
            isLoading: false,
            isLoadingTail: false,
            dataSource: new ListViewDataSource({
                rowHasChanged: (row1, row2) => row1 !== row2,
            }),
            filter: '',
            queryNumber: 0,
        };
    },

    componentDidMount: function() {
        this.searchUsers('');
    },

    handleData: function(query, cursor) {
        queryToLoading[query] = false;
        queryToCursor[query] = cursor;

        var data = queryToData[query] ? queryToData[query].slice() : [];
        for (var i in cursor.currentPageOrderedEntries) {
            data.push(cursor.currentPageOrderedEntries[i]);
        }
        queryToData[query] = data;

        if (this.state.filter !== query) {
            // do not update state if the query is stale
            return;
        }

        this.setState({
            dataSource: this.getDataSource(queryToData[query]),
            isLoading: false,
            isLoadingTail: false
        });
    },

    handleError: function(error) {
        queryToLoading[query] = false;
        queryToCursor[query] = undefined;
        queryToData[query] = undefined;

        this.setState({
            dataSource: this.getDataSource([]),
            isLoading: false,
            isLoadingTail: false
        });

    },

    searchUsers: function(query: string) {
        queryToLoading[query] = true;
        queryToCursor[query] = null;
        queryToData[query] = null;

        this.setState({
            isLoading: true,
            isLoadingTail: false,
            filter: query,
            queryNumber: this.state.queryNumber + 1
        });

        var queryParts = query.split(/ /);
        var queryFirst = queryParts.length == 2 ? queryParts[0] : query;
        var queryLast = queryParts.length == 2 ? queryParts[1] : query;
        var queryOp = queryParts.length == 2 ? "AND" : "OR";
        var querySpec = {queryType:"smart", 
                         smartSql:"SELECT {users:_soup}"
                         + " FROM {users}"
                         + " WHERE {users:FirstName} like '" + queryFirst + "%'"
                         + " " + queryOp + " {users:LastName} like '" + queryLast + "%'"
                         + " ORDER BY {users:LastName} ",
                         pageSize:10}

        var that = this;
        smartstore.runSmartQuery(querySpec,                                          
                                 function(cursor) {
                                     that.handleData(query, cursor);
                                 }, 
                                 this.handleError);
    },

    hasMore: function(): boolean {
        var query = this.state.filter;
        var cursor = queryToCursor[query];
        if (!cursor) {
            return true;
        }
        else {
            return cursor.currentPageIndex + 1 < cursor.totalPages;
        }
    },

    onEndReached: function() {
        var query = this.state.filter;
        if (!this.hasMore() || this.state.isLoadingTail) {
            // We're already fetching or have all the elements so noop
            return;
        }

        if (queryToLoading[query]) {
            return;
        }
        queryToLoading[query] = true;
        this.setState({
            queryNumber: this.state.queryNumber + 1,
            isLoadingTail: true,
        });

        var cursor = queryToCursor[query];
        console.log("Getting next page - currently at page:" + cursor.currentPageIndex);
        var that = this;
        smartstore.moveCursorToNextPage(cursor, 
                                        function(cursor) {
                                            that.handleData(query, cursor);
                                        }, 
                                        this.handleError);
    },

    getDataSource: function(users: Array<any>): ListViewDataSource {
        return this.state.dataSource.cloneWithRows(users);
    },

    selectUser: function(user: Object) {
        this.props.navigator.push({
            title: user.Title,
            component: UserScreen,
            passProps: {user},
        });
    },

    onSearchChange: function(event: Object) {
        var filter = event.nativeEvent.text.toLowerCase();

        this.clearTimeout(this.timeoutID);
        this.timeoutID = this.setTimeout(() => this.searchUsers(filter), 100);
    },

    renderFooter: function() {
        if (!this.hasMore() || !this.state.isLoadingTail) {
            return <View style={styles.scrollSpinner} />;
        }
        return <ActivityIndicatorIOS style={styles.scrollSpinner} />;
    },

    renderRow: function(row: Object)  {
        return (
                <UserCell
                  onSelect={() => this.selectUser(row[0])}
                  user={row[0]}
                />
        );
    },

    render: function() {
        var content = this.state.dataSource.getRowCount() === 0 ?
            <NoUsers
              filter={this.state.filter}
              isLoading={this.state.isLoading}
            /> :
            <ListView
              ref="listview"
              dataSource={this.state.dataSource}
              renderFooter={this.renderFooter}
              renderRow={this.renderRow}
              onEndReached={this.onEndReached}
              automaticallyAdjustContentInsets={false}
              keyboardDismissMode={ScrollView.keyboardDismissMode.OnDrag}
              keyboardShouldPersistTaps={true}
              showsVerticalScrollIndicator={false}
            />;

        return (
                <View style={styles.container}>
                  <SearchBar
                    onSearchChange={this.onSearchChange}
                    isLoading={this.state.isLoading}
                    onFocus={() => this.refs.listview.getScrollResponder().scrollTo(0, 0)}
                  />
                <View style={styles.separator} />
                {content}
                <Footer/>
                </View>
        );
    },
});

var NoUsers = React.createClass({
    render: function() {
        var text = '';
        if (this.props.filter) {
            text = `No results for “${this.props.filter}”`;
        } else if (!this.props.isLoading) {
            text = 'No users found';
        }

        return (
                <View style={[styles.container, styles.centerText]}>
                <Text style={styles.noUsersText}>{text}</Text>
                </View>
        );
    }
});

var SearchBar = React.createClass({
    render: function() {
        return (
                <View style={styles.searchBar}>
                <TextInput
                  autoCapitalize={TextInput.autoCapitalizeMode.none}
                  autoCorrect={false}
                  onChange={this.props.onSearchChange}
                  placeholder="Search a user..."
                  onFocus={this.props.onFocus}
                  style={styles.searchBarInput}
                />
                <ActivityIndicatorIOS
                  animating={this.props.isLoading}
                  style={styles.spinner}
                />
                </View>
        );
    }
});

var styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: 'white',
    },
    centerText: {
        alignItems: 'center',
    },
    noUsersText: {
        marginTop: 80,
        color: '#888888',
    },
    searchBar: {
        marginTop: 64,
        padding: 3,
        paddingLeft: 8,
        flexDirection: 'row',
        alignItems: 'center',
    },
    searchBarInput: {
        fontSize: 15,
        flex: 1,
        height: 30,
    },
    separator: {
        height: 1,
        backgroundColor: '#eeeeee',
    },
    spinner: {
        width: 30,
    },
    scrollSpinner: {
        marginVertical: 20,
    },
});

module.exports = SearchScreen;

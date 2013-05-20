#!/usr/bin/env node

var commandLineArgs = process.argv.slice(2, process.argv.length);
var command = commandLineArgs.shift();
if (typeof command !== 'string') {
    usage();
    process.exit(1);
}

switch  (command) {
    case 'create':
      createApp();
      break;
    default:
      console.log('Unknown option: \'' + command + '\'.');
      usage();
      process.exit(2);
}

function usage() {
    console.log('Usage:');
    console.log('forceios create');
    console.log('    -t <Application Type> (native, hybrid_remote, hybrid_local)');
    console.log('    -n <Application Name>');
    console.log('    -c <Company Identifier> (com.myCompany.myApp)');
    console.log('    -g <Organization Name> (your company\'s/organization\'s name)');
    console.log('    [-o <Output directory> (defaults to this script\'s directory)');
    console.log('    [-a <Salesforce App Identifier>] (the Consumer Key for your app)');
    console.log('    [-u <Salesforce App Callback URL] (the Callback URL for your app)');
    console.log('    [-s <App Start Page> (defaults to index.html for hybrid_local, and /apex/VFStartPage for hybrid_remote)');
}

function createApp() {
    var appType = getAppTypeFromArgs();
    var appTypeIsNative;
    switch (appType) {
    	case null:
    	    console.log('App type was not specified in command line arguments.');
    	    usage();
    	    process.exit(3);
    	    break;
    	case 'native':
    	    appTypeIsNative = true;
    	    break;
    	case 'hybrid_remote':
    	case 'hybrid_local':
    	    appTypeIsNative = false;
    	    break;
    	default:
    	    console.log('Unrecognized app type: ' + appType);
          usage();
    	    process.exit(4);
    }

    var exec = require('child_process').exec,
        path = require('path'),
        createAppExecutable = (appTypeIsNative ? 
                                  path.join(__dirname, 'templates', 'NativeAppTemplate', 'createApp.sh') :
                                  path.join(__dirname, 'templates', 'HybridAppTemplate', 'createApp.sh')
                              );
    
    var createAppProcess = exec(createAppExecutable + ' ' + commandLineArgs.join(' '), function (error, stdout, stderr) {
        if (stdout) console.log(stdout);
        if (stderr) console.log(stderr);
        if (error !== null) {
            console.log('There was an error creating the app.');
        } else {
            console.log('Congratulations!  You have successfully created your app.');
        }
    });
}

function getAppTypeFromArgs() {
    var i = 0;
	  var gotAppTypeFlag = false;
	  while (i < commandLineArgs.length && !gotAppTypeFlag) {
		    if (commandLineArgs[i] === '-t')
		      gotAppTypeFlag = true;
		    else
			    i++;
	  }

	  if (!gotAppTypeFlag)
		    return null;
	  if (i >= commandLineArgs.length - 1)
		    return null;

	  return commandLineArgs[i + 1];
}
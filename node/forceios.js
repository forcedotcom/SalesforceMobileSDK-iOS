#!/usr/bin/env node

var version = '5.0.0',
    shelljs = require('shelljs'),
    exec = require('child_process').exec,
    fs = require('fs'),
    path = require('path'),
    commandLineUtils = require('../external/shared/node/commandLineUtils'),
    miscUtils = require('../external/shared/node/utils'),
    cordovaHelper = require('../external/shared/node/cordovaHelper');

var minimumCordovaCliVersion = '5.4.0';
var cordovaPlatformVersion = '4.2.0';

var outputColors = {
    'red': '\x1b[31;1m',
    'green': '\x1b[32;1m',
    'yellow': '\x1b[33;1m',
    'magenta': '\x1b[35;1m',
    'cyan': '\x1b[36;1m',
    'reset': '\x1b[0m'
}

var dependencyType = {
    'FILE': 0,
    'DIR': 1,
    'ARCHIVE': 2,
    'DIRCONTENTS': 3
}

// Calling main
main(process.argv);

//
// Main function
//
function main(args) {
    var commandLineArgs = process.argv.slice(2, args.length);
    var command = commandLineArgs.shift();

    var processorList = null;
    var commandHandler = null;

    switch (command || '') {
    case 'version':
        console.log('forceios version ' + version);
        process.exit(0);
        break;
    case 'create':
        processorList = createArgProcessorList();
        commandHandler = createApp;
        break;
    default:
        usage();
        process.exit(1);
    }

    commandLineUtils.processArgsInteractive(commandLineArgs, processorList, commandHandler);
}


//
// Usage
//
function usage() {
    console.log(outputColors.cyan + 'Usage:\n');
    console.log(outputColors.magenta + 'forceios create');
    console.log('    --apptype=<Application Type> (native, native_swift, react_native, hybrid_remote, hybrid_local)');
    console.log('    --appname=<Application Name>');
    console.log('    --companyid=<Company Identifier> (com.myCompany.myApp)');
    console.log('    --organization=<Organization Name> (Your company\'s/organization\'s name)');
    console.log('    --startpage=<App Start Page> (The start page of your remote app. Only required for hybrid_remote)');
    console.log('    [--outputdir=<Output directory> (Defaults to the current working directory)]');
    console.log('    [--appid=<Salesforce App Identifier> (The Consumer Key for your app. Defaults to the sample app.)]');
    console.log('    [--callbackuri=<Salesforce App Callback URL (The Callback URL for your app. Defaults to the sample app.)]');
    console.log(outputColors.cyan + '\n OR \n');
    console.log(outputColors.magenta + 'forceios version' + outputColors.reset);
}

//
// Helper for 'create' command
//
function createApp(config) {
    // Native app creation
    if (config.apptype === 'native' || config.apptype === 'native_swift' || config.apptype === 'react_native') {
        createNativeApp(config);
    }
    // Hybrid app creation
    else {
        createHybridApp(config);
    }
}

//
// Helper to create hybrid application
//
function createHybridApp(config) {
    var outputDir = config.outputdir;

    var projectDir;
    if(!outputDir)
        projectDir = path.join(process.cwd(),config.appname);
    else
        projectDir = path.resolve(outputDir);

    // Make sure the Cordova CLI client exists.
    var cordovaCliVersion = cordovaHelper.getCordovaCliVersion();
    if (cordovaCliVersion === null) {
        console.log('cordova command line tool could not be found.  Make sure you install the cordova CLI from https://www.npmjs.org/package/cordova.');
        process.exit(11);
    }

    var minimumCordovaCliVersionNum = miscUtils.getVersionNumberFromString(minimumCordovaCliVersion);
    var cordovaCliVersionNum = miscUtils.getVersionNumberFromString(cordovaCliVersion);
    if (cordovaCliVersionNum < minimumCordovaCliVersionNum) {
        console.log('Installed cordova command line tool version (' + cordovaCliVersion + ') is less than the minimum required version (' + minimumCordovaCliVersion + ').  Please update your version of Cordova.');
        process.exit(12);
    }

    console.log('Using cordova CLI version ' + cordovaCliVersion + ' to create the hybrid app.');

    shelljs.exec('cordova create "' + projectDir + '" ' + config.companyid + ' ' + config.appname);
    shelljs.pushd(projectDir);
    shelljs.exec('cordova platform add ios@' + cordovaPlatformVersion);
    shelljs.exec('cordova plugin add https://github.com/forcedotcom/SalesforceMobileSDK-CordovaPlugin#unstable');

    // Remove the default Cordova app.
    shelljs.rm('-rf', path.join('www', '*'));

    // Copy the sample app, if a local app was selected.
    if (config.apptype === 'hybrid_local') {
        var sampleAppFolder = path.join(__dirname, '..', 'external', 'shared', 'samples', 'userlist');
        shelljs.cp('-R', path.join(sampleAppFolder, '*'), 'www');
    }

    // Add bootconfig.json
    var bootconfig = {
        "remoteAccessConsumerKey": config.appid || "3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa",
        "oauthRedirectURI": config.callbackuri || "testsfdc:///mobilesdk/detect/oauth/done",
        "oauthScopes": ["web", "api"],
        "isLocal": config.apptype === 'hybrid_local',
        "startPage": config.startpage || 'index.html',
        "errorPage": "error.html",
        "shouldAuthenticate": true,
        "attemptOfflineLoad": false
    };
    // console.log("Bootconfig:" + JSON.stringify(bootconfig, null, 2));

    fs.writeFileSync(path.join('www', 'bootconfig.json'), JSON.stringify(bootconfig, null, 2));
    shelljs.exec('cordova prepare ios');
    shelljs.popd();

    // Inform the user of next steps.
    var nextStepsOutput =
        ['',
         outputColors.green + 'Your application project is ready in ' + projectDir + '.',
         '',
         outputColors.cyan + 'To build the new application, do the following:' + outputColors.reset,
         '   - cd ' + projectDir,
         '   - cordova build',
         '',
         outputColors.cyan + 'To run the application, start an emulator or plug in your device and run:' + outputColors.reset,
         '   - cordova run',
         '',
         outputColors.cyan + 'To use your new application in XCode, do the following:' + outputColors.reset,
         '   - open ' + projectDir + '/platforms/ios/' + config.appname + '.xcodeproj in XCode',
         '   - build and run',
         ''].join('\n');
    console.log(nextStepsOutput);
    console.log(outputColors.cyan + 'Before you ship, make sure to plug your OAuth Client ID,\nCallback URI, and OAuth Scopes into '
        + outputColors.magenta + 'www/bootconfig.json' + outputColors.reset);
}

//
// Helper to create native application
//
function createNativeApp(config) {
    var createAppExecutable = path.join(__dirname, '..', 'build', 'app_template_files', 'createApp.sh');

    // Calling out to the shell, so re-quote the command line arguments.
    var newCommandLineArgs = buildArgsFromArgMap(config);
    var createAppProcess = exec(createAppExecutable + ' ' + newCommandLineArgs, function(error, stdout, stderr) {
        if (error) {
            console.log(outputColors.red + 'There was an error creating the app.' + outputColors.reset);
            process.exit(3);
        }
    });
    createAppProcess.stdout.on('data', function(data) { console.log(data.toString('utf8')); });
    createAppProcess.stderr.on('data', function(data) { console.log(data.toString('utf8')); });
}

function buildArgsFromArgMap(config) {
    var argLine = '';
    argLine += ' -t "' + config.apptype + '"';
    argLine += ' -n "' + config.appname + '"';
    argLine += ' -c "' + config.companyid + '"';
    argLine += ' -g "' + config.organization + '"';
    if (config.outputdir)
        argLine += ' -o "' + config.outputdir + '"';
    if (config.appid)
        argLine += ' -a "' + config.appid + '"';
    if (config.callbackuri)
       argLine += ' -u "' + config.callbackuri + '"';

    return argLine;
}


// -----
// Input argument validation / processing.
// -----

function createArgProcessorList() {

    var argProcessorList = new commandLineUtils.ArgProcessorList();

    // App type
    addProcessorFor(argProcessorList, 'apptype', 'Enter your application type (native, native_swift, react_native, hybrid_remote, or hybrid_local):', 'App type must be native, native_swift, react_native, hybrid_remote, or hybrid_local.',
                    function(val) { return ['native', 'native_swift', 'react_native', 'hybrid_remote', 'hybrid_local'].indexOf(val) >= 0; });

    // App name
    addProcessorFor(argProcessorList, 'appname', 'Enter your application name:', 'Invalid value for application name: \'$val\'.', /^\S+$/);

    // Output dir
    addProcessorForOptional(argProcessorList, 'outputdir', 'Enter the output directory for your app (defaults to the current directory):');

    // Company Identifier
    addProcessorFor(argProcessorList, 'companyid', 'Enter the package name for your app (com.mycompany.my_app):', 'Invalid value for company identifier: \'$val\'', /^[a-z]+[a-z0-9_]*(\.[a-z]+[a-z0-9_]*)*$/);

    // Organization
    addProcessorFor(argProcessorList, 'organization', 'Enter your organization name (Acme, Inc.):', 'Invalid value for organization: \'$val\'.',  /\S+/);

    // Start page
    addProcessorFor(argProcessorList, 'startpage', 'Enter the start page for your app (only applicable for hybrid_remote apps):', 'Invalid value for start page: \'$val\'.', /\S+/,
                    function(argsMap) { return (argsMap['apptype'] === 'hybrid_remote'); });

    // Connected App ID
    addProcessorForOptional(argProcessorList, 'appid', 'Enter your Connected App ID (defaults to the sample app\'s ID):');

    // Connected App Callback URI
    addProcessorForOptional(argProcessorList, 'callbackuri', 'Enter your Connected App Callback URI (defaults to the sample app\'s URI):');

    return argProcessorList;
}

//
// Helper function to add arg processor
// * argProcessorList: ArgProcessorList
// * argName: string, name of argument
// * prompt: string for prompt
// * error: string for error (can contain $val to print the value typed by the user in the error message)
// * validation: function or regexp or null (no validation)
// * preprocessor: function or null
// * postprocessor: function or null
//
function addProcessorFor(argProcessorList, argName, prompt, error, validation, preprocessor, postprocessor) {
   argProcessorList.addArgProcessor(argName, prompt, function(val) {
       val = val.trim();

       // validation is either a function or a regexp
       if (typeof validation === 'function' && validation(val)
           || typeof validation === 'object' && typeof validation.test === 'function' && validation.test(val))
       {
           return new commandLineUtils.ArgProcessorOutput(true, typeof postprocessor === 'function' ? postprocessor(val) : val);
       }
       else {
           return new commandLineUtils.ArgProcessorOutput(false, error.replace('$val', val));
       }

   }, preprocessor);
}

//
// Helper function to add arg processor for optional arg- should unset value when nothing is typed in
// * argProcessorList: ArgProcessorList
// * argName: string, name of argument
// * prompt: string for prompt
//
function addProcessorForOptional(argProcessorList, argName, prompt) {
    addProcessorFor(argProcessorList, argName, prompt, undefined, function() { return true;}, undefined, undefined);
}

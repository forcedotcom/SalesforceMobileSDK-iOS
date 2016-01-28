#!/usr/bin/env node

var version='4.1.0',
    execSync = require('child_process').execSync,
    path = require('path'),
    shelljs = require('shelljs');

var outputColors = {
    'red': '\x1b[31;1m',
    'green': '\x1b[32;1m',
    'yellow': '\x1b[33;1m',
    'magenta': '\x1b[35;1m',
    'cyan': '\x1b[36;1m',
    'reset': '\x1b[0m'
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
    case 'all':
        cleanup();
        var tmpDir = mkTmpDir();
        generateForceiosPackage();
        deployForceios(tmpDir);
        var appName = createApp(tmpDir, 'native');
        compileApp(tmpDir, appName);
        break;
    default:
        usage();
        process.exit(1);
    }
}

//
// Usage
//
function usage() {
    console.log(outputColors.cyan + 'Usage:\n');
    console.log(outputColors.magenta + 'test_forceios.js all' + outputColors.reset);
}

//
// Return random number between n/10 and n
//
function random(n) {
    return (n/10)+Math.floor(Math.random()*(9*n/10));
}

//
// Cleanup
//
function cleanup() {
    console.log(outputColors.green + 'Cleaning up temp dirs' + outputColors.reset);
    shelljs.rm('-rf', 'tmp');
}

//
// Make temp dir and return its path
//
function mkTmpDir() {
    var tmpDir = path.join('tmp', 'testforceios' + random(1000));
    console.log(outputColors.green + 'Making temp dir' + tmpDir + outputColors.reset);
    shelljs.mkdir('-p', tmpDir);
    return tmpDir;
}

//
// Run ant on build_npm.xml to generate forceios.tgz
//
function generateForceiosPackage() {
    console.log(outputColors.green + 'Generating forceios package' + outputColors.reset);
    runProcess('ant -f ' + path.join(__dirname, '..', 'build', 'build_npm.xml'));
}

//
// Move forceios.tgz to temp dir and npm install it
//
function deployForceios(tmpDir) {
    console.log(outputColors.green + 'Deployinng forceios package' + outputColors.reset);
    shelljs.mv(path.join(__dirname, '..', 'forceios-' + version + '.tgz'), tmpDir);
    runProcess('npm install --prefix ' + tmpDir + ' ' + path.join(tmpDir, 'forceios-' + version + '.tgz'));
}

//
// Create app with forceios and return app name
//
function createApp(tmpDir, appType) {
    console.log(outputColors.green + 'Creating ' + appType + ' app ' + outputColors.reset);
    var appName = appType;
    var appId = '3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa';
    var callbackUri = 'testsfdc:///mobilesdk/detect/oauth/done';

    var forceiosPath = path.join(tmpDir, 'node_modules', '.bin', 'forceios');
    var forceiosArgs = 'create '
        + ' --apptype=' + appType
        + ' --appname=' + appName
        + ' --companyid=com.mycompany'
        + ' --organization=MyCompany'
        + ' --outputdir=' + tmpDir
        + ' --appid=' + appId
        + ' --callbackuri=' + callbackUri;
    runProcess(forceiosPath + ' ' + forceiosArgs);
    return appName;
}

//
// Compile app
//
function compileApp(tmpDir, appName) {
    console.log(outputColors.green + 'Compiling ' + appName + outputColors.reset);
    var workspacePath = path.join(tmpDir, appName, appName + '.xcworkspace');
    runProcess('xcodebuild -workspace ' + workspacePath + ' -scheme Pods-' + appName)
}

//
// Helper to run arbitrary shell command
//
function runProcess(cmd) {
    console.log(outputColors.reset + 'Running: ' + cmd);
    var childProcess = execSync(cmd);
}


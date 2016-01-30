#!/usr/bin/env node

var version='4.1.0',
    execSync = require('child_process').execSync,
    path = require('path'),
    shelljs = require('shelljs'),
    commandLineUtils = require('../external/shared/node/commandLineUtils')
;

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
    var parsedArgs = commandLineUtils.parseArgs(commandLineArgs);

    if (parsedArgs.hasOwnProperty('usage')) {
        usage();
        process.exit(1);
    }
    else {
        var fork = parsedArgs.fork || 'forcedotcom';
        var branch = parsedArgs.branch || 'unstable';
        var chosenAppTypes = parsedArgs.test;
        
        cleanup();
        var tmpDir = mkTmpDir();
        var repoDir = cloneRepo(tmpDir, 'https://github.com/' + fork + '/SalesforceMobileSDK-iOS', branch);
        createDeployForceiosPackage(repoDir, tmpDir);

        var nativeAppTypes = ['native', 'native_swift', 'react_native'];
        var hybridAppTypes = ['hybrid_local', 'hybrid_remote'];
        for (var i = 0; i<nativeAppTypes.length; i++) {
            var appType = nativeAppTypes[i];
            if (chosenAppTypes.indexOf(appType) >= 0) createCompileApp(tmpDir, appType);
        }
        for (var i = 0; i<hybridAppTypes.length; i++) {
            var appType = hybridAppTypes[i];
            if (chosenAppTypes.indexOf(appType) >= 0) createCompileHybridApp(tmpDir, appType);
        }
    }
}

//
// Usage
//
function usage() {
    log('Usage:',  'cyan');
    log('  test_forceios.js --usage\n'
        + 'OR \n'
        + '  test_forceios.js\n'
        + '    [--fork=FORK (defaults to forcedotcom)]\n'
        + '    [--branch=BRANCH (defaults to unstable)]\n'
        + '    [--test=appType1,appType2,etc]\n'
        + '      where appTypes are in: native, native_swift, react_native, hybrid_local, hybrid_remote\n'
        + '\n'
        + '  Clone https://github.com/FORK/SalesforceMobileSDK-iOS at branch BRANCH\n'
        + '  Generate forceios package and deploys it to a temporary directory\n'
        + '  Create and compile the application types selected\n'
        , 'magenta');
}

//
// Cleanup
//
function cleanup() {
    log('Cleaning up temp dirs', 'green');
    shelljs.rm('-rf', 'tmp');
}

//
// Make temp dir and return its path
//
function mkTmpDir() {
    var tmpDir = path.join('tmp', 'testforceios' + random(1000));
    log('Making temp dir:' + tmpDir, 'green');
    shelljs.mkdir('-p', tmpDir);
    return tmpDir;
}

//
// Clone iOS repo and return its path
// 
function cloneRepo(tmpDir, repoUrl, branch) {
    log('Cloning ' + repoUrl + ' at ' + branch, 'green');
    var repoDir = path.join(tmpDir, 'SalesforceMobileSDK-iOS');
    shelljs.mkdir('-p', repoDir);
    runProcess('git clone --branch ' + branch + ' --single-branch --depth 1 --recurse-submodules ' + repoUrl + ' ' + repoDir);
    return repoDir;
}

//
// Create and deploy forceios
//
function createDeployForceiosPackage(repoDir, tmpDir) {
    log('Generating forceios package', 'green');
    runProcess('ant -f ' + path.join(repoDir, 'build', 'build_npm.xml'));
    runProcess('npm install --prefix ' + tmpDir + ' ' + path.join(repoDir, 'forceios-' + version + '.tgz'));
}

//
// Create and compile non-hybrid app 
//
function createCompileApp(tmpDir, appType) {
    log('Creating ' + appType + ' app ', 'green');
    var appName = appType + 'App';
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

    // Pointing to repoDir in Podfile
    shelljs.sed('-i', /pod ('Salesforce.*')/g, 'pod $1, :path => \'../SalesforceMobileSDK-iOS\'', path.join(tmpDir, 'nativeApp', 'Podfile'));
    shelljs.sed('-i', /pod ('Smart.*')/g, 'pod $1, :path => \'../SalesforceMobileSDK-iOS\'', path.join(tmpDir, 'nativeApp', 'Podfile'));

    shelljs.pushd(path.join(tmpDir, appName));
    runProcess('pod update');    
    shelljs.popd();

    var workspacePath = path.join(tmpDir, appName, appName + '.xcworkspace');
    runProcess('xcodebuild -workspace ' + workspacePath + ' -scheme Pods-' + appName)
}

//
// Create and compile hybrid app 
//
function createCompileHybridApp(tmpDir, appType) {
    log('Creating ' + appType + ' app ', 'green');
    var appName = appType + 'App';
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
    if (appType === 'hybrid_remote') {
        forceiosArgs += ' --startPage=/apex/testPage';
    }
    runProcess(forceiosPath + ' ' + forceiosArgs);
    shelljs.pushd(path.join(tmpDir, appName));
    runProcess('cordova build');    
    shelljs.popd();
}


//
// Helper to run arbitrary shell command
//
function runProcess(cmd) {
    log('Running: ' + cmd);
    try {
        execSync(cmd);
    } catch (err) {
        log('!Failed!', 'red');
        console.error(err.stderr.toString());
    }
}

//
// Print important information
//
function log(msg, color) {
    if (color) {
        console.log(outputColors[color] + msg + outputColors.reset);
    }
    else {
        console.log(msg);
    }
}


//
// Return random number between n/10 and n
//
function random(n) {
    return (n/10)+Math.floor(Math.random()*(9*n/10));
}


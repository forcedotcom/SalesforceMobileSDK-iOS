

# Native SDK Test Infrastructure

Included with this release are several ways to test the Salesforce Mobile for iOS native SDK:

- Unit tests for simulator: SalesforceSDKTests target
- Unit tests for device ("app tests" per Apple): AppTest target
- ant build scripts that allow running tests from the command line

The unit tests connect to a live Salesforce instance (sandbox by default), and so you will need to have a valid network connection between your simulator/device and the Salesforce instance.

Before submitting any pull requests for SalesforceSDK native code, please ensure that all unit tests pass. If you are adding new functionality not already covered by existing unit tests, please add unit tests as appropriate and ensure that they pass.

## Required Credentials

In order to run any of the unit tests, you will need to overwrite the "test\_credentials.json" file with valid oauth credentials.
The simplest way to obtain these is by using the RestExplorer application.  

Simply open the RestExplorer app on either simulator or device, login to your favorite sandbox (test.salesforce.com) org , and then 
"Export credentials to pasteboard" (then cmd-C copy the credentials from simulator or eg email them to yourself from the device).

Once you have these credentials, you paste them whole into the "test\_credentials.json" file referenced from the SalesforceSDKTests application ( "SalesforceSDKTests/Supporting Files/test_credentials.json").  

The test_credentials.json file is included in the test bundle and read by the test code (TestSetupUtils.m).  

Note that you may obtain credentials for your own Remote Access object from your own sandbox or production org by editing the settings in RestAPIExplorerAppDelegate.m.  Specifically you will need create or obtain a Remote Access object from your org and edit:

- remoteAccessConsumerKey
- OAuthRedirectURI
- OAuthLoginDomain

For information on how to setup a Remote Access object for your org, see:
[About Remote Access](http://login.salesforce.com/help/doc/en/remoteaccess_about.htm) 


## Running unit tests from XCode

To run tests in a simulator from xcode, simply select the SalesforceSDK target, select Simulator, and Product -> Test (cmd-U). Test failures will be reported by xcode.

To run tests on a tethered device, select the AppTest target, select "iOS Device", and and Product -> Test (cmd-U).  Test failures will be reported by xcode. 

## Running unit tests from the command line 

Currently only running unit tests in the simulator is supported from the command line.
If you cd to /native/SalesforceSDK/sfdc_build and run the command "ant all", the ant unit testing target will be run as part of the full build.  Unit test failures will be reported in the console output. 

Unit tests run from the command line will generate a code coverage report at:
/native/SalesforceSDK/sfdc_build/artifacts/coverage.xml

This details which code was covered by the tests executed.
 

## Discussion

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you.  Post any feedback you have to the [Mobile Community Discussion Board](http://boards.developerforce.com/t5/Mobile/bd-p/mobile) on developerforce.com.

You can also report issues and make enhancement requests at
[MobileSDK for iOS GitHub Page](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/issues)


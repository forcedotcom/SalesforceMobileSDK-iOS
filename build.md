# Building the Salesforce Mobile SDK for iOS

You can build the different library packages and application templates with the build tools in the `build/` folder.  The SDK uses `ant` as its build tool, and `build.xml` contains all of the different build targets to generate libraries and templates.

The default target, `all`, will build all of the core, native, and hybrid libraries, as well as the application templates and the scripts for generating new apps from the templates.  These will be stored in the `build/artifacts` folder.

## Using the app templates

The native and hybrid app templates can be found in the `NativeAppTemplate` and `HybridAppTemplate` build artifacts folders, respectively.  You can generate an app by running the `createApp.sh` script inside the folder.  Running the script without arguments will show you the usage details.  After the script has run, your app can be found in the same folder as the template, under your app's folder name.

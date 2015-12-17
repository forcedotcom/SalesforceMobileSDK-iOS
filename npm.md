# Salesforce Mobile SDK for iOS Package

The **forceios** npm package allows users to create iOS mobile applications to interface with the [Salesforce Platform](http://www.salesforce.com/platform/overview/), leveraging the [Salesforce Mobile SDK for iOS](https://github.com/forcedotcom/SalesforceMobileSDK-iOS).

## Getting Started

If you're new to mobile development, or the force.com platform, you may want to start at the [Mobile SDK landing page](http://wiki.developerforce.com/page/Mobile_SDK).  This page offers a variety of resources to help you determine the best technology path for creating your app, as well as many guides and blog posts detailing how to work with the Mobile SDK.

But assuming you're all read up, here's how to get started with the **forceios** package to create the starting point for your mobile application.

## Install the forceios Package

Because forceios is a command-line utility, we recommend installing it globally, so that it's easily accessible on your path:

        sudo npm install forceios -g

You're of course welcome to install it locally as well:

        npm install forceios

In this case, you can access the forceios app at `[Install Directory]/node_modules/.bin/forceios`.

## Using forceios

For the rest of this document, we'll assume that `forceios` is on your path.

Typing `forceios` with no arguments gives you a breakdown of the usage:

        $ forceios
        Usage:
        forceios create
            --apptype=<Application Type> (native, hybrid_remote, hybrid_local)
            --appname=<Application Name>
            --companyid=<Company Identifier> (com.myCompany.myApp)
            --organization=<Organization Name> (Your company's/organization's name)
            --startpage=<App Start Page> (The start page of your remote app. Only required for hybrid_remote)
            [--outputdir=<Output directory> (Defaults to the current working directory)]
            [--appid=<Salesforce App Identifier> (The Consumer Key for your app. Defaults to the sample app.)]
            [--callbackuri=<Salesforce App Callback URL (The Callback URL for your app. Defaults to the sample app.)]

        OR 

        forceios version

**Note:** You can specify any or all of the arguments as command line options as specified in the usage.  If you run `forceios create` with missing arguments, it prompts you for each missing option interactively.

Once the creation script completes, you'll have a fully functioning basic application of the type you specified.  The new application is an Xcode project that you can peruse, run, and debug.

### forceios create options

**App Type:** The type of application you wish to develop:

- **native** — A fully native iOS application
- **hybrid\_remote** — A hybrid application, based on the [Cordova](http://cordova.apache.org/) framework, that runs in a native container.  The app contents live in the cloud as a [Visualforce](http://wiki.developerforce.com/page/An_Introduction_to_Visualforce) application
- **hybrid\_local** — A hybrid application, based on the Cordova framework, that runs in a native container.  The app contents are developed locally in the Xcode project, and are deployed to the device itself when the app is built

**App Name:** The name of your application

**Company ID:** An identifier for your company, similar to a Java package (e.g. `com.acme.MobileApps`).  This concatenates with the app name to form the unique identifier for your app in the App Store.

**Organization:** The name of your company or organization.  For example, `Acme Widgets, Inc.`

**Start Page:** \( *Required for hybrid\_remote apps only* \) The starting page of your application on salesforce.com.  This is the entry point of your remote application, though it's only the path, not the server portion of the URL.  For instance, `/apex/MyVisualforceStartPage`.

**Output Directory:** \( *optional* \) The directory where you want your app to be created.  If not specified, it will be created in your current working directory.

**App ID:** \( *optional* \) The Connected App Consumer Key that identifies your app in the cloud.  This argument defaults to a sample key to allow you to test your app.  However, **you _must_ specify your own Consumer Key before you submit your app to the App Store**.

**Callback URI:** \( *optional* \) The Callback URL associated with your Connected App.  As with the App ID, this argument defaults to a value for a sample app.  **You _must_ specify your own Callback URL before you submit your app to the App Store**.

## More information

- The Salesforce Mobile SDK for Android (and package) source repository lives [here](https://github.com/forcedotcom/SalesforceMobileSDK-Android).

- See [our developerforce site](http://wiki.developerforce.com/page/Mobile_SDK) for more information about how you can leverage the Salesforce Mobile SDK with the force.com platform.

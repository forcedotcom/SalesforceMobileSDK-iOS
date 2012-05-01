


# About this Visualforce sample app

This app was generated from the Salesforce Mobile SDK Hybrid Force.com app template. This template provides some things that you may find useful for Force.com Hybrid apps:

- A bootconfig.js file that allows you to configure the app login/logout behavior (see below).
- A Settings screen that allows the user to pick an instance (ie Production or Sandbox) or force a logout the next time the app reopens.
- A bootstrap.html page that detects instance changes, logs the user out if requested in Settings, and walks through the initial login process.  

# Customization

The bootconfig.js file contains all the available variables for customizing the behavior of the template app.

Generally we expect that developers will use this template as a starting point to build two different kinds of apps: 

1. Visualforce-based Apps, where most of the app content is stored on the server, and is retrieved from the server as needed
2. Local REST-based apps, where the app content is stored within the application bundle, and data is retrieved from the server using REST calls. 

# Visualforce Apps

- Ensure that your oauthScopes includes "web"
- Set your startPage to the path of your Visualforce page on the server instance, beginning with "apex/". 
- Set autoRefreshOnForeground to true.  This will cause the app container to refresh your oauth session each time the app is foregrounded. This helps avoid problems with session timeout. 
- Setup your Visualforce page on your org instance, ensuring that the instance matches the instance you're trying to access from your mobile app: ie if you are accessing Sandbox, you will need to login to test.salesforce.com, if you are accessing Production, you will need to login to login.salesforce.com


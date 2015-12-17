# About this REST + PhoneGap sample app

This app was generated from the Salesforce Mobile SDK Hybrid Force.com app template. This template provides some things that you may find useful for Force.com Hybrid apps:

- A bootconfig.json file that allows you to configure the app login/logout behavior (see below).
- A Settings screen that allows the user to pick an instance (ie Production or Sandbox) or force a logout the next time the app reopens.
- A bootstrap.html page that detects instance changes, logs the user out if requested in Settings, and walks through the initial login process.  
- An example index.html page that shows how you might use the forcetk.js REST library to access the Force.com REST API from javascript.

# Customization

The bootconfig.json file contains all the available variables for customizing the behavior of the template app.

Generally we expect that developers will use this template as a starting point to build two different kinds of apps: 

1. Visualforce-based Apps, where most of the app content is stored on the server, and is retrieved from the server as needed
2. Local REST-based apps, where the app content is stored within the application bundle, and data is retrieved from the server using REST calls. 


# Local REST-based Apps

- Ensure that your oauthScopes includes "api"
- Set your startPage to the empty string "".  This will automatically load your index.html file after login completes.
- Set autoRefreshOnForeground to true.  This will cause the app container to refresh your oauth session each time the app is foregrounded. This helps avoid problems with session timeout. 
- Edit the index.html to suit your needs.  The example index.html provided shows how you might access a couple different CRM object types, but you can easily modify this to access other types.

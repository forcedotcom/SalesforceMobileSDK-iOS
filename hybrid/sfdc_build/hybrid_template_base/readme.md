# Setup

Additional steps to be completed once your project has been created.

- Open the project and remove the www folder (Right-click the www folder in the Project Navigator, select Delete from the popup menu, and click "Remove References Only")
- Re-add the www folder. Right-click the project name folder in the Project Navigator, Add Files, and select the www folder in the file selection dialog. Be sure that "Create folder references for any added folders" is selected

Your project is now ready to be compiled.

# Troubleshooting

==
I get this error shortly after login:
'ERROR: Start Page at \'www/index.html\' was not found.'  (visible in the web view)

You need to remove and re-add the www folder to your project.  See the instructions above.
==

# About this Template-Generated App

This app was generated from the Salesforce Mobile SDK Hybrid Force.com app template. This template provides some things that you may find useful for Force.com Hybrid apps:

- A bootconfig.js file that allows you to configure the app login/logout behavior (see below).
- A Settings screen that allows the user to pick an instance (ie Production or Sandbox) or force a logout the next time the app reopens.
- A bootstrap.html page that detects instance changes, logs the user out if requested in Settings, and walks through the initial login process.  
- An example index.html page that shows how you might use the forcetk.js REST library to access the Force.com REST API from javascript.

# Customization

The bootconfig.js file contains all the available variables for customizing the behavior of the template app.

Generally we expect that developers will use this template as a starting point to build two different kinds of apps: 

1. Visualforce-based Apps, where most of the app content is stored on the server, and is retrieved from the server as needed
2. Local REST-based apps, where the app content is stored within the application bundle, and data is retrieved from the server using REST calls. 

# Visualforce Apps

- Ensure that your oauthScopes includes "visualforce"
- Set your startPage to the path of your Visualforce page on the server instance, beginning with "apex/". 
- Set autoRefreshOnForeground to true.  This will cause the app container to refresh your oauth session each time the app is foregrounded. This helps avoid problems with session timeout. 
- Setup your Visualforce page on your org instance, ensuring that the instance matches the instance you're trying to access from your mobile app: ie if you are accessing Sandbox, you will need to login to test.salesforce.com, if you are accessing Production, you will need to login to login.salesforce.com

# Local REST-based Apps

- Ensure that your oauthScopes includes "api"
- Set your startPage to the empty string "".  This will automatically load your index.html file after login completes.
- Set autoRefreshOnForeground to true.  This will cause the app container to refresh your oauth session each time the app is foregrounded. This helps avoid problems with session timeout. 
- Edit the index.html to suit your needs.  The example index.html provided shows how you might access a couple different CRM object types, but you can easily modify this to access other types.

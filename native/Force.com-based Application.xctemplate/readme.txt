Additional steps to be completed once your project has been created.

1. Click your project icon (the first item in your project tree)   
2. Click on the main target
3. Click on the tab Build Settings.  
4. Click All
5. In the search field, enter Other Linker Flags
6. Set Other Linker Flags to -ObjC -all_load
7. Now click on the Build Phases tab. Expand the Link Binary With Libraries box, and click +
8. In the search box, type libxml2. Select libxml2.dylib, and click Add. 

Your project is now ready to be compiled.

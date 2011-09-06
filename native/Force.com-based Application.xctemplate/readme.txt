Additional steps to be completed once your project has been created.

1. Open the Build Settings tab for the project.
2. Set Other Linker Flags to -ObjC -all_load
3. Open the Build Phases tab for the project main target.
4. Link against the following required framework: libxml2.dylib

Your project is now ready to be compiled.
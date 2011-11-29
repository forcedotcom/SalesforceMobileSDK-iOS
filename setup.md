# Setup


Installation
==

To setup external submodules such as RestKit, run the installation script in this directory:
`./install.sh`

This also performs a build of all libraries required by the sample apps, as well as the
sample apps themselves.  In addition it installs the Force.com app templates into the default
XCode projects template location under ~/Library/Developer/Xcode/Templates. 
(This allows to you create new projects of either type __Native Force.com-based App__ or 
__Hybrid Force.com-based App__ directly from Xcode.)


Merging changes from Public Repo using git
==

After you git clone, you need to add the upstream repo (pointing to the public repo):

`git remote add upstream git@github.com:forcedotcom/SalesforceMobileSDK-iOS.git`

To pull changes from our public repo:

`git fetch upstream`
`git merge upstream/master`





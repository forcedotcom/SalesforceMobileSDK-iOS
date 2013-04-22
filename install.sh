#!/bin/bash

#
# Run this script before working with the SalesforceMobileSDK Xcode workspace.
#

ORIG_CWD=`pwd`
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$SCRIPT_DIR"
git submodule init
git submodule sync
git submodule update 
cd "$ORIG_CWD"


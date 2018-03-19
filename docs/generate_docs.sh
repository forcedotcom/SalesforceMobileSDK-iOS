#!/bin/bash

#
# Run this script from the root of the repo to generate docs for the libraries in this workspace.
# The generated docs are placed under the 'build/artifacts/doc' folder.
#

# Generates Obj-C library docs.
ant -buildfile build/build_doc.xml

# Generates Swift library docs.
jazzy --config docs/jazzy.yaml

#!/bin/sh
(JS_DIR=`pwd`/js; cd Pods/React; npm run start -- --root $JS_DIR)

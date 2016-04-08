#!/bin/bash

usage() {
    [ $# -eq 0 ] || echo "$*" >&2
cat <<EOF >&2
usage: $0 [options] <files_or_directories>...
options:
    -b=<build_dir>      Build directory (defaults to \$BUILD_DIR, or './build')
    -c=<configuration>  Configuration (defaults to \$CONFIGURATION, or 'Release')
    -h                  Help

EOF
    exit 1
}

OPT_HELP=
OPT_BUILD=
OPT_CONFIGURATION=
while getopts "b:c:h" opt; do
    case $opt in
        h) OPT_HELP=1 ;;
        b) OPT_BUILD=$OPTARG ;;
        c) OPT_CONFIGURATION=$OPTARG ;;
        \?) usage "Invalid option: -$opt" ;;
        :) usage "Option -$opt requires an argument." ;;
    esac
done
shift $((OPTIND-1))

[[ $OPT_HELP ]] && usage

if [[ -n $OPT_BUILD ]]; then
    export BUILD_DIR=$OPT_BUILD;
elif [[ -z $BUILD_DIR ]]; then
    export BUILD_DIR=`(cd $(dirname $0)/..; pwd)`/build
fi

if [[ -n $OPT_CONFIGURATION ]]; then
    export CONFIGURATION=$OPT_CONFIGURATION
elif [[ -z $CONFIGURATION ]]; then
    export CONFIGURATION=Release
fi

FRAMEWORK_SCHEME=SalesforceKit-iOS
FRAMEWORK_NAME=SalesforceKit
PROJECT_NAME=SalesforceKit
SIMULATOR_LIBRARY_PATH="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_NAME}.framework"
DEVICE_LIBRARY_PATH="${BUILD_DIR}/${CONFIGURATION}-iphoneos/${FRAMEWORK_NAME}.framework"
UNIVERSAL_LIBRARY_DIR="${BUILD_DIR}/${CONFIGURATION}-iphoneuniversal"
FRAMEWORK="${UNIVERSAL_LIBRARY_DIR}/${FRAMEWORK_NAME}.framework"

echo "##############################"
echo "# Build Simulator Frameworks #"
echo "##############################"

xcodebuild -project ${PROJECT_NAME}.xcodeproj \
    -sdk iphonesimulator \
    -scheme ${FRAMEWORK_SCHEME} \
    -configuration ${CONFIGURATION} \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="i386 x86_64" \
    VALID_ARCHS="i386 x86_64" \
    CONFIGURATION_BUILD_DIR=${BUILD_DIR}/${CONFIGURATION}-iphonesimulator \
    clean build

echo "###########################"
echo "# Build Device Frameworks #"
echo "###########################"

xcodebuild -project ${PROJECT_NAME}.xcodeproj \
    -sdk iphoneos \
    -scheme ${FRAMEWORK_SCHEME} \
    -configuration ${CONFIGURATION} \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="armv7 armv7s arm64" \
    VALID_ARCHS="armv7 armv7s arm64" \
    CONFIGURATION_BUILD_DIR=${BUILD_DIR}/${CONFIGURATION}-iphoneos \
    clean build

echo "############################"
echo "# Package universal binary #"
echo "############################"

rm -rf "${FRAMEWORK}"
mkdir -p "${FRAMEWORK}"

cp -r "${DEVICE_LIBRARY_PATH}/." "${FRAMEWORK}"

lipo -create -output "${FRAMEWORK}/${FRAMEWORK_NAME}" \
    "${SIMULATOR_LIBRARY_PATH}/${FRAMEWORK_NAME}" \
    "${DEVICE_LIBRARY_PATH}/${FRAMEWORK_NAME}"

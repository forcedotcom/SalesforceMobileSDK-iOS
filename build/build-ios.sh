#!/bin/bash

usage() {
    [ $# -eq 0 ] || echo "$*" >&2
cat <<EOF >&2
usage: $0 [options] <files_or_directories>...
options:
    -b <build_dir>      Build directory (defaults to \$BUILD_DIR, or './build')
    -c <configuration>  Configuration (defaults to \$CONFIGURATION, or 'Release')
    -B <build_num>      Build number (defaults to \$BUILD_NUMBER)
    -o <output>         Output artifacts path (defaults to 'artifacts')
    -s <identity>       Code signing identity
    -f <name>           Framework name
    -g <scheme>         Framework scheme (defaults to the framework name)
    -h                  Help

EOF
    exit 1
}

FRAMEWORK_NAME=
PROJECT_NAME=SalesforceMobileSDK

OPT_HELP=
OPT_BUILD=
OPT_BUILD_NUMBER=$BUILD_NUMBER
OPT_CONFIGURATION=
OPT_OUTPUT=
OPT_CODE_SIGN_IDENTITY=
OPT_FRAMEWORK_NAME=
OPT_FRAMEWORK_SCHEME=
while getopts "o:b:B:c:s:h:f:g:" opt; do
    case $opt in
        h) OPT_HELP=1 ;;
        o) OPT_OUTPUT=$OPTARG ;;
        b) OPT_BUILD=$OPTARG ;;
        B) OPT_BUILD_NUMBER=$OPTARG ;;
        c) OPT_CONFIGURATION=$OPTARG ;;
        s) OPT_CODE_SIGN_IDENTITY=$OPTARG ;;
        f) OPT_FRAMEWORK_NAME=$OPTARG ;;
        g) OPT_FRAMEWORK_SCHEME=$OPTARG ;;
        \?) usage "Invalid option: -$opt" ;;
        :) usage "Option -$opt requires an argument." ;;
    esac
done
shift $((OPTIND-1))

[[ $OPT_HELP ]] && usage

if [[ -n $OPT_FRAMEWORK_NAME ]]; then
    echo "SET"
    echo $OPT_FRAMEWORK_NAME
    FRAMEWORK_NAME="$OPT_FRAMEWORK_NAME"
fi

FRAMEWORK_SCHEME="$FRAMEWORK_NAME"
if [[ -n $OPT_FRAMEWORK_SCHEME ]]; then
    FRAMEWORK_SCHEME="$OPT_FRAMEWORK_SCHEME"
fi

ROOT=`(cd $(dirname $0)/../; pwd)`

if [[ -n $OPT_BUILD ]]; then
    export BUILD_DIR=$OPT_BUILD;
elif [[ -z $BUILD_DIR ]]; then
    export BUILD_DIR=$ROOT/build
fi

if [[ -z $OPT_OUTPUT ]]; then
    if [[ -n $WORKSPACE ]]; then
        OPT_OUTPUT="$WORKSPACE/build/artifacts"
    else
        OPT_OUTPUT="$ROOT/build/artifacts"
    fi
fi

# If using the KPP plugin then add the keychain to the build machine
if [[ ! -z CODE_SIGNING_IDENTITY ]]; then
    OPT_CODE_SIGN_IDENTITY=$CODE_SIGNING_IDENTITY
fi

if [[ -n $OPT_CONFIGURATION ]]; then
    export CONFIGURATION=$OPT_CONFIGURATION
elif [[ -z $CONFIGURATION ]]; then
    export CONFIGURATION=Release
fi

OUTPUT_FRAMEWORK_NAME="$FRAMEWORK_NAME"

SIMULATOR_LIBRARY_PATH="$BUILD_DIR/$CONFIGURATION-iphonesimulator/$FRAMEWORK_NAME.framework"
DEVICE_LIBRARY_PATH="$BUILD_DIR/$CONFIGURATION-iphoneos/$FRAMEWORK_NAME.framework"
UNIVERSAL_LIBRARY_DIR="$BUILD_DIR/$CONFIGURATION-iphoneuniversal"

if [[ -n $OPT_BUILD_NUMBER ]]; then
    BUILD_VERSION_SUFFIX=".$OPT_BUILD_NUMBER"
fi

xcodebuild -workspace "$ROOT/$PROJECT_NAME.xcworkspace" \
    -sdk iphonesimulator \
    -scheme "$FRAMEWORK_SCHEME" \
    -configuration "$CONFIGURATION" \
    BUILD_NUMBER=$OPT_BUILD_NUMBER \
    BUILD_VERISON_SUFFIX="$BUILD_VERISON_SUFFIX" \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="i386 x86_64" \
    VALID_ARCHS="i386 x86_64" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/$CONFIGURATION-iphonesimulator" \
    clean build

#If a codesign identity is set use it
if [[ ! -z OPT_CODE_SIGN_IDENTITY ]]; then
    xcodebuild -workspace "$ROOT/$PROJECT_NAME.xcworkspace" \
        -sdk iphoneos \
        -scheme "$FRAMEWORK_SCHEME" \
        -configuration "$CONFIGURATION" \
        BUILD_NUMBER=$OPT_BUILD_NUMBER \
        BUILD_VERISON_SUFFIX="$BUILD_VERISON_SUFFIX" \
        BITCODE_GENERATION_MODE=bitcode \
        ONLY_ACTIVE_ARCH=NO \
        ARCHS="armv7 armv7s arm64"  \
        VALID_ARCHS="armv7 armv7s arm64"  \
        CONFIGURATION_BUILD_DIR="$BUILD_DIR/$CONFIGURATION-iphoneos" \
        CODE_SIGN_IDENTITY="$OPT_CODE_SIGN_IDENTITY" \
        clean build
else
    xcodebuild -workspace "$ROOT/$PROJECT_NAME.xcworkspace" \
        -sdk iphoneos \
        -scheme "$FRAMEWORK_SCHEME" \
        -configuration "$CONFIGURATION" \
        BUILD_NUMBER=$OPT_BUILD_NUMBER \
        BUILD_VERISON_SUFFIX="$BUILD_VERISON_SUFFIX" \
        BITCODE_GENERATION_MODE=bitcode \
        ONLY_ACTIVE_ARCH=NO \
        ARCHS="armv7 armv7s arm64"  \
        VALID_ARCHS="armv7 armv7s arm64"  \
        CONFIGURATION_BUILD_DIR="$BUILD_DIR/$CONFIGURATION-iphoneos" \
        clean build
fi

mkdir -p "$OPT_OUTPUT/$CONFIGURATION"
rm -rf "$OPT_OUTPUT/$CONFIGURATION/$OUTPUT_FRAMEWORK_NAME.framework"
cp -r "$DEVICE_LIBRARY_PATH/." "$OPT_OUTPUT/$CONFIGURATION/$OUTPUT_FRAMEWORK_NAME.framework"
lipo -create -output "$OPT_OUTPUT/$CONFIGURATION/$OUTPUT_FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
    "$SIMULATOR_LIBRARY_PATH/$FRAMEWORK_NAME" \
    "$DEVICE_LIBRARY_PATH/$FRAMEWORK_NAME"

if [[ "$CONFIGURATION" = "Release" ]]; then
    cp -r "$BUILD_DIR/$CONFIGURATION-iphoneos/$FRAMEWORK_NAME.framework.dSYM" "$OPT_OUTPUT/$CONFIGURATION/$OUTPUT_FRAMEWORK_NAME.framework.dSYM"
    lipo -create -output "$OPT_OUTPUT/$CONFIGURATION/$OUTPUT_FRAMEWORK_NAME.framework.dSYM/Contents/Resources/DWARF/$FRAMEWORK_NAME"         \
        "$BUILD_DIR/$CONFIGURATION-iphonesimulator/$FRAMEWORK_NAME.framework.dSYM/Contents/Resources/DWARF/$FRAMEWORK_NAME" \
        "$BUILD_DIR/$CONFIGURATION-iphoneos/$FRAMEWORK_NAME.framework.dSYM/Contents/Resources/DWARF/$FRAMEWORK_NAME"
fi

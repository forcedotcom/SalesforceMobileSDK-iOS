#!/bin/bash
# This script generates a wrapper header for the supplied header path

info() {
    echo [ INFO  ] $* >&2
}

warn() {
    echo [ WARN  ] $* >&2
}

usage() {
    [ $# -eq 0 ] || warn "$*"
cat <<EOF >&2
usage: $0 [options] <files_or_directories>...
options:
    -o=<output_header>   Path for the output header wrapper
    -n=<name>            Name of the SDK (default: derived from the output filename)
    -f                   Force to run from outside of Xcode
    -h                   Help
    -v                   Verbose mode

EOF
    exit 1
}

OPT_HELP=
OPT_VERBOSE=
OPT_FORCE=
OPT_UMBRELLA=
OPT_NAME=
OPT_OUTPUT=
while getopts "vhfn:o:u:" opt; do
    case $opt in
        h) OPT_HELP=1 ;;
        v) OPT_VERBOSE=1 ;;
        f) OPT_FORCE=1 ;;
        n) OPT_NAME=$OPTARG ;;
        u) OPT_UMBRELLA=$OPTARG ;;
        o) OPT_OUTPUT=$OPTARG ;;
        \?) usage "Invalid option: -$opt" ;;
        :) usage "Option -$opt requires an argument." ;;
    esac
done
shift $((OPTIND-1))

[[ $OPT_HELP ]] && usage

[[ -z $OPT_OUTPUT ]] && usage "You must specify an output filename"

if [[ -z $OPT_NAME ]]; then
    OPT_NAME=$(basename "$OPT_OUTPUT" | awk -F. '{print $1}')
fi

[[ $OPT_VERBOSE ]] && info "Generating headers for $OPT_OUTPUT"

user=$(id -P | awk -F: '{ print $8 }')
wrapper_filename=$(basename $OPT_OUTPUT)
wrapper_directory=$(dirname $OPT_OUTPUT)

[[ -d $wrapper_directory ]] || mkdir -p $wrapper_directory

# Resolve directory path if it's a symlink
if [[ -L "$wrapper_directory" ]]; then
    wrapper_directory="$(dirname $wrapper_directory)/$(readlink $wrapper_directory)"
fi

# Records the import of the original umbrella header file, if it exists.
# This will be used later to update the original file if needed.
orig_imports=""
if [[ -f $OPT_UMBRELLA ]]; then
    while read line; do
        if [[ "$line" =~ ^#import ]]; then
            orig_imports=`echo "${orig_imports}${line}"`
        fi
    done < "$OPT_UMBRELLA"
fi

# Records the import of the existing umbrella header file, if it exists.
# This will be used later to update the existing file if needed.
existing_imports=""
if [[ -f $OPT_OUTPUT ]]; then
    while read line; do
        if [[ "$line" =~ ^#import ]]; then
            existing_imports=`echo "${existing_imports}${line}"`
        fi
    done < "$OPT_OUTPUT"
fi

# Re-create the umbrella header file in a temporary
# location and copy it only if it is different from
# the existing umbrella header file.
# This is done to avoid re-creating the same file again
# which will cause Xcode to rebuild the entire project.
OPT_TEMP=$(mktemp -t umbrella)

updated_imports=""
cat <<EOF > "$OPT_TEMP"
/*
 $wrapper_filename
 $OPT_NAME

 Created by $user on $(date).

 Copyright (c) $(date +"%Y")-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

EOF

for file in $(find $wrapper_directory -type f); do
    filename=$(basename $file)
    if [[ $filename == $wrapper_filename ]]; then
        continue;
    fi
    # The Swift header imports the umbrella header, skip the Swift header here to avoid circular dependency
    if [[ $filename == "$OPT_NAME-Swift.h" ]]; then
        continue;
    fi
    import_line=`echo "#import <$OPT_NAME/$filename>"`
    updated_imports=`echo "${updated_imports}${import_line}"`
    echo "$import_line" >> $OPT_TEMP
done

# If there was an original file, and the updated import file differs from the original, update the original.
if [[ "$orig_imports" != "" ]]; then
    if [[ "$orig_imports" != "$updated_imports" ]]; then
        cp "$OPT_TEMP" "$OPT_UMBRELLA"
    fi
fi

# If there was an existing file, and the updated import file differs from the existing, update the existing.
# If there was no existing file, copy the updated file to the existing file location.
if [[ "$existing_imports" != "" ]]; then
    if [[ "$existing_imports" != "$updated_imports" ]]; then
        cp "$OPT_TEMP" "$OPT_OUTPUT"
    fi
else
    cp "$OPT_TEMP" "$OPT_OUTPUT"
fi


#!/bin/bash

#
# Run this script from the root of the repo to generate docs for the libraries in this workspace.
# The generated docs are placed under the 'build/artifacts/doc' folder.
#
# This script uses DocC (Apple's Documentation Compiler) to generate documentation.
# Requires Xcode 13+ to be installed.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LIBS_DIR="libs"
OUTPUT_DIR="build/artifacts/doc"
DERIVED_DATA_DIR="build/DerivedData"
DESTINATION="generic/platform=iOS Simulator"

# Libraries to document
LIBRARIES=(
    "SalesforceSDKCommon"
    "SalesforceAnalytics"
    "SalesforceSDKCore"
    "SmartStore"
    "MobileSync"
)

echo -e "${GREEN}Starting DocC documentation generation...${NC}"

# Clean and create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build documentation for each library
for lib in "${LIBRARIES[@]}"; do
    echo -e "\n${YELLOW}Building documentation for $lib...${NC}"

    PROJECT_PATH="$LIBS_DIR/$lib/$lib.xcodeproj"

    if [ ! -d "$PROJECT_PATH" ]; then
        echo -e "${RED}Error: Project not found at $PROJECT_PATH${NC}"
        continue
    fi

    # Build documentation using xcodebuild docbuild
    xcodebuild docbuild \
        -scheme "$lib" \
        -project "$PROJECT_PATH" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        | grep -E "Build Succeeded|error:|warning:|note:" || true

    # Find the generated .doccarchive
    DOCCARCHIVE=$(find "$DERIVED_DATA_DIR/Build/Products" -name "$lib.doccarchive" -type d | head -n 1)

    if [ -z "$DOCCARCHIVE" ]; then
        echo -e "${RED}Warning: Documentation archive not found for $lib${NC}"
        continue
    fi

    # Convert to static HTML for GitHub Pages hosting
    echo "Converting to static HTML..."
    $(xcrun --find docc) process-archive transform-for-static-hosting \
        "$DOCCARCHIVE" \
        --output-path "$OUTPUT_DIR/$lib" \
        --hosting-base-path "/Documentation/$lib"

    echo -e "${GREEN}✓ Documentation for $lib generated successfully${NC}"
done

# Create an index page for easy navigation
cat > "$OUTPUT_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Salesforce Mobile SDK for iOS - Documentation</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1 { color: #032e61; }
        .library-list {
            list-style: none;
            padding: 0;
        }
        .library-list li {
            margin: 15px 0;
            padding: 15px;
            background: #f5f5f5;
            border-radius: 5px;
            transition: background 0.2s;
        }
        .library-list li:hover {
            background: #e8e8e8;
        }
        .library-list a {
            text-decoration: none;
            color: #0070d2;
            font-size: 18px;
            font-weight: 500;
        }
        .library-list a:hover {
            text-decoration: underline;
        }
        .description {
            color: #666;
            font-size: 14px;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <h1>Salesforce Mobile SDK for iOS</h1>
    <p>Welcome to the Salesforce Mobile SDK for iOS documentation. Choose a library to view its API reference:</p>

    <ul class="library-list">
        <li>
            <a href="/Documentation/SalesforceSDKCommon/">SalesforceSDKCommon</a>
            <div class="description">Common utilities and components shared across the SDK</div>
        </li>
        <li>
            <a href="/Documentation/SalesforceAnalytics/">SalesforceAnalytics</a>
            <div class="description">Analytics and instrumentation framework</div>
        </li>
        <li>
            <a href="/Documentation/SalesforceSDKCore/">SalesforceSDKCore</a>
            <div class="description">Core SDK functionality including authentication and networking</div>
        </li>
        <li>
            <a href="/Documentation/SmartStore/">SmartStore</a>
            <div class="description">Encrypted offline storage solution</div>
        </li>
        <li>
            <a href="/Documentation/MobileSync/">MobileSync</a>
            <div class="description">Data synchronization framework</div>
        </li>
    </ul>

    <hr style="margin-top: 40px;">
    <p style="color: #666; font-size: 14px;">
        For more information, visit the
        <a href="https://github.com/forcedotcom/SalesforceMobileSDK-iOS">GitHub repository</a>.
    </p>
</body>
</html>
EOF

# Clean up derived data
rm -rf "$DERIVED_DATA_DIR"

echo -e "\n${GREEN}Documentation generation complete!${NC}"
echo -e "Documentation HTML files are available at: ${YELLOW}$OUTPUT_DIR${NC}"
echo -e "\nGenerated documentation structure:"
for lib in "${LIBRARIES[@]}"; do
    echo -e "  - $OUTPUT_DIR/$lib/"
done
echo -e "  - $OUTPUT_DIR/index.html (navigation page)"

echo -e "\n${YELLOW}Note:${NC} Documentation is optimized for GitHub Pages hosting."
echo -e "The docs are configured to be hosted at: ${GREEN}/Documentation/${NC}"
echo -e "\nTo test locally (simulating GitHub Pages structure):"
echo -e "  1. Create a test directory: ${GREEN}mkdir -p /tmp/ghpages/Documentation${NC}"
echo -e "  2. Copy docs: ${GREEN}cp -r $OUTPUT_DIR/* /tmp/ghpages/Documentation/${NC}"
echo -e "  3. Start server: ${GREEN}cd /tmp/ghpages && python3 -m http.server 8080${NC}"
echo -e "  4. Open: ${GREEN}http://localhost:8080/Documentation/${NC}"

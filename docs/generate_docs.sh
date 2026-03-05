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

# Ensure we run from the repository root (parent of docs/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Configuration
LIBS_DIR="libs"
OUTPUT_DIR="build/artifacts/doc"
DERIVED_DATA_DIR="build/DerivedData"
DESTINATION="generic/platform=iOS Simulator"
# GitHub Pages base path (forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/...)
HOSTING_BASE="/SalesforceMobileSDK-iOS/Documentation"

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

    # Find the generated .doccarchive (may be under Debug-iphonesimulator or similar)
    DOCCARCHIVE=$(find "$DERIVED_DATA_DIR" -name "$lib.doccarchive" -type d | head -n 1)

    if [ -z "$DOCCARCHIVE" ]; then
        echo -e "${RED}Warning: Documentation archive not found for $lib${NC}"
        continue
    fi

    echo "doc archive -> $DOCCARCHIVE"

    # Convert to static HTML for GitHub Pages hosting
    echo "Converting to static HTML..."
    $(xcrun --find docc) process-archive transform-for-static-hosting \
        "$DOCCARCHIVE" \
        --output-path "$OUTPUT_DIR/$lib" \
        --hosting-base-path "$HOSTING_BASE/$lib"

    # DocC does not apply hosting-base-path to the root index.html, so fix asset
    # URLs for subdirectory hosting (local test and GitHub Pages).
    LIB_INDEX="$OUTPUT_DIR/$lib/index.html"
    if [ -f "$LIB_INDEX" ]; then
        BASE_PREFIX="$HOSTING_BASE/$lib"
        sed -i.bak "s|var baseUrl = \"/\"|var baseUrl = \"$BASE_PREFIX/\"|" "$LIB_INDEX"
        sed -i.bak "s|src=\"/|src=\"$BASE_PREFIX/|g" "$LIB_INDEX"
        sed -i.bak "s|href=\"/|href=\"$BASE_PREFIX/|g" "$LIB_INDEX"
        rm -f "$LIB_INDEX.bak"
    fi

    # DocC renderer fetches theme-settings.json; 404 causes "page not found". Add minimal file if missing.
    if [ ! -f "$OUTPUT_DIR/$lib/theme-settings.json" ]; then
        echo '{"theme":{}}' > "$OUTPUT_DIR/$lib/theme-settings.json"
    fi

    echo -e "${GREEN}✓ Documentation for $lib generated successfully${NC}"
done

# Generate static HTML fallback for each library (no JavaScript required)
echo -e "\n${YELLOW}Generating static HTML fallbacks...${NC}"
for lib in "${LIBRARIES[@]}"; do
    MODULE_ID=$(echo "$lib" | tr '[:upper:]' '[:lower:]')
    MODULE_JSON="$OUTPUT_DIR/$lib/data/documentation/$MODULE_ID.json"
    if [ ! -f "$MODULE_JSON" ] && [ -d "$OUTPUT_DIR/$lib/data/documentation" ]; then
        # DocC may use a different module name (e.g. from bundle); use first .json in data/documentation
        MODULE_JSON=$(find "$OUTPUT_DIR/$lib/data/documentation" -maxdepth 1 -name "*.json" -type f 2>/dev/null | head -n 1)
    fi
    STATIC_HTML="$OUTPUT_DIR/$lib/static-index.html"
    if [ -n "$MODULE_JSON" ] && [ -f "$MODULE_JSON" ]; then
    python3 - "$MODULE_JSON" "$lib" "$STATIC_HTML" "$HOSTING_BASE" << 'PYTHON_SCRIPT' || true
import json, sys, html
from pathlib import Path
mod_path = Path(sys.argv[1])
lib_name = sys.argv[2]
out_path = Path(sys.argv[3])
hosting_base = sys.argv[4] if len(sys.argv) > 4 else "/Documentation"
try:
    data = json.loads(mod_path.read_text(encoding="utf-8"))
except Exception:
    data = {}
refs = data.get("references") or {}
def abstract_text(ref):
    if not isinstance(ref, dict):
        return ""
    blocks = ref.get("abstract") or []
    return " ".join(b.get("text", "") for b in blocks if isinstance(b, dict)).strip()
def ref_title(r):
    if not isinstance(r, dict):
        return ""
    name = r.get("title")
    if name:
        return str(name)
    nt = r.get("navigatorTitle")
    if isinstance(nt, list) and nt:
        return str(nt[0].get("text") or nt[0].get("kind", ""))
    if isinstance(nt, str):
        return nt
    return ""
sections_html = []
for sec in data.get("topicSections") or []:
    title = sec.get("title", "") or ""
    ids = sec.get("identifiers") or []
    if not ids:
        continue
    items = []
    for doc_id in ids:
        r = refs.get(doc_id) or {}
        name = ref_title(r) or "(symbol)"
        abstract = abstract_text(r)
        url = (r.get("url") or "").strip()
        if url and not url.startswith("/"):
            url = "/" + url
        # Link to DocC-generated topic page (same structure as swift.org: .../documentation/{module}/{symbol}/)
        if url:
            topic_url = f"{hosting_base}/{lib_name}/documentation{url}".rstrip("/") + "/"
            link = f'<a href="{html.escape(topic_url)}">{html.escape(name)}</a>'
        else:
            link = html.escape(name)
        items.append(f"<li>{link}" + (f" — {html.escape(abstract)}" if abstract else "") + "</li>")
    sections_html.append(f"<h2>{html.escape(title)}</h2><ul>{''.join(items)}</ul>")
base = f"{hosting_base}/{lib_name}"
# Link to the real DocC module overview page (same URL structure as swift.org/documentation)
module_overview_url = f"{base}/documentation/{mod_path.stem}/"
body = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{html.escape(lib_name)} — API Reference</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1.5rem; line-height: 1.5; }}
h1 {{ color: #032e61; }}
.nav {{ margin: 1rem 0; font-size: 0.95rem; }}
h2 {{ margin-top: 1.5rem; color: #333; font-size: 1.1rem; }}
ul {{ list-style: none; padding: 0; }}
li {{ margin: 0.5rem 0; padding: 0.25rem 0; border-bottom: 1px solid #eee; }}
a {{ color: #0070d2; text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
.pill {{ display: inline-block; background: #e8f4fc; color: #0070d2; padding: 0.25rem 0.75rem; border-radius: 1rem; font-size: 0.9rem; margin-bottom: 0.5rem; margin-right: 0.5rem; }}
</style>
</head>
<body>
<nav class="nav"><a href="{hosting_base}/">Documentation</a> › {html.escape(lib_name)}</nav>
<h1>{html.escape(lib_name)}</h1>
<p><a class="pill" href="{module_overview_url}">Browse full documentation</a> <a class="pill" href="{base}/docc-app.html#/documentation/{mod_path.stem}">Single-page app</a></p>
<p>Symbols below link to the generated topic pages. Use “Browse full documentation” for the full DocC experience.</p>
{"".join(sections_html)}
<hr>
<p><a href="{hosting_base}/">← Documentation index</a></p>
</body>
</html>"""
out_path.write_text(body, encoding="utf-8")
PYTHON_SCRIPT
    else
        # No module JSON or discovery failed: create minimal static page with link to interactive app
        MODULE_ID=$(echo "$lib" | tr '[:upper:]' '[:lower:]')
        cat > "$STATIC_HTML" << STATICEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$lib — Documentation</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1.5rem; line-height: 1.5; }
h1 { color: #032e61; }
.pill { display: inline-block; background: #e8f4fc; color: #0070d2; padding: 0.25rem 0.75rem; border-radius: 1rem; font-size: 0.9rem; margin-bottom: 1rem; }
a { color: #0070d2; text-decoration: none; }
a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h1>$lib</h1>
<p><a class="pill" href="$HOSTING_BASE/$lib/documentation/$MODULE_ID/">Browse full documentation</a></p>
<p>API reference is available via the link above (requires JavaScript).</p>
<hr>
<p><a href="$HOSTING_BASE/">← Documentation index</a></p>
</body>
</html>
STATICEOF
    fi
    # If Python failed or produced nothing, ensure we have at least a minimal static page
    if [ ! -f "$STATIC_HTML" ] && [ -f "$OUTPUT_DIR/$lib/index.html" ]; then
        MODULE_ID=$(echo "$lib" | tr '[:upper:]' '[:lower:]')
        cat > "$STATIC_HTML" << STATICEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$lib — Documentation</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1.5rem; }
h1 { color: #032e61; }
.pill { display: inline-block; background: #e8f4fc; color: #0070d2; padding: 0.25rem 0.75rem; border-radius: 1rem; font-size: 0.9rem; margin-bottom: 1rem; }
a { color: #0070d2; }
</style>
</head>
<body>
<h1>$lib</h1>
<p><a class="pill" href="$HOSTING_BASE/$lib/documentation/$MODULE_ID/">Browse full documentation</a></p>
<hr>
<p><a href="$HOSTING_BASE/">← Documentation index</a></p>
</body>
</html>
STATICEOF
    fi
    # Replace the DocC root index with the static one so the library URL shows content without JS
    BASE_PREFIX="$HOSTING_BASE/$lib"
    if [ -f "$OUTPUT_DIR/$lib/index.html" ] && [ -f "$STATIC_HTML" ]; then
        mv "$OUTPUT_DIR/$lib/index.html" "$OUTPUT_DIR/$lib/docc-app.html"
        mv "$STATIC_HTML" "$OUTPUT_DIR/$lib/index.html"
    fi
    # Ensure docc-app.html (or index.html if static wasn't generated) has correct asset paths for subdirectory
    for candidate in "$OUTPUT_DIR/$lib/docc-app.html" "$OUTPUT_DIR/$lib/index.html"; do
        if [ -f "$candidate" ] && grep -q 'src="/js/' "$candidate" 2>/dev/null; then
            sed -i.bak "s|var baseUrl = \"/\"|var baseUrl = \"$BASE_PREFIX/\"|" "$candidate"
            sed -i.bak "s|src=\"/|src=\"$BASE_PREFIX/|g" "$candidate"
            sed -i.bak "s|href=\"/|href=\"$BASE_PREFIX/|g" "$candidate"
            rm -f "${candidate}.bak"
        fi
    done
done

# Create an index page for easy navigation (Swift DocC–style: Documentation home with clear links)
get_lib_description() {
    case "$1" in
        SalesforceSDKCommon) echo "Common utilities and components shared across the SDK" ;;
        SalesforceAnalytics) echo "Analytics and instrumentation framework" ;;
        SalesforceSDKCore) echo "Core SDK functionality including authentication and networking" ;;
        SmartStore) echo "Encrypted offline storage solution" ;;
        MobileSync) echo "Data synchronization framework" ;;
        *) echo "API reference" ;;
    esac
}
{
    echo '<!DOCTYPE html>'
    echo '<html lang="en">'
    echo '<head>'
    echo '  <meta charset="UTF-8">'
    echo '  <meta name="viewport" content="width=device-width, initial-scale=1.0">'
    echo '  <title>Salesforce Mobile SDK for iOS — Documentation</title>'
    echo '  <style>'
    echo '    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 820px; margin: 2rem auto; padding: 0 1.5rem; line-height: 1.6; }'
    echo '    h1 { color: #032e61; }'
    echo '    .lib { margin: 1rem 0; padding: 1rem; background: #f5f5f5; border-radius: 6px; }'
    echo '    .lib h2 { margin: 0 0 0.5rem 0; font-size: 1.1rem; }'
    echo '    .lib a { color: #0070d2; text-decoration: none; }'
    echo '    .lib a:hover { text-decoration: underline; }'
    echo '    .lib .meta { color: #666; font-size: 0.9rem; margin-top: 0.25rem; }'
    echo '  </style>'
    echo '</head>'
    echo '<body>'
    echo '  <h1>Documentation</h1>'
    echo '  <p>Salesforce Mobile SDK for iOS. Choose a library:</p>'
    echo '  <ul style="list-style: none; padding: 0;">'
    for lib in "${LIBRARIES[@]}"; do
        mod_id=$(echo "$lib" | tr '[:upper:]' '[:lower:]')
        desc=$(get_lib_description "$lib")
        echo "    <li class=\"lib\">"
        # Relative paths so links work on GitHub Pages (username.github.io/repo-name/Documentation/) and locally
        echo "      <h2><a href=\"$lib/documentation/$mod_id/\">$lib</a></h2>"
        echo "      <div class=\"meta\">$desc</div>"
        echo "    </li>"
    done
    echo '  </ul>'
    echo '  <hr style="margin-top: 2rem;">'
    echo '  <p style="color: #666; font-size: 0.9rem;">'
    echo '    <a href="https://github.com/forcedotcom/SalesforceMobileSDK-iOS">GitHub repository</a>'
    echo '  </p>'
    echo '</body>'
    echo '</html>'
} > "$OUTPUT_DIR/index.html"

# Clean up derived data
# rm -rf "$DERIVED_DATA_DIR"

echo -e "\n${GREEN}Documentation generation complete!${NC}"
echo -e "Documentation HTML files are available at: ${YELLOW}$OUTPUT_DIR${NC}"
echo -e "\nGenerated documentation structure:"
for lib in "${LIBRARIES[@]}"; do
    echo -e "  - $OUTPUT_DIR/$lib/"
done
echo -e "  - $OUTPUT_DIR/index.html (navigation page)"

echo -e "\n${YELLOW}Note:${NC} Documentation is generated for GitHub Pages at ${GREEN}${HOSTING_BASE}/${NC}"

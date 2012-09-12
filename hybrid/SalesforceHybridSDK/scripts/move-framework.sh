FW_DST_DIR=${SRCROOT}/../dependencies/SalesforceHybridSDK
MY_FW=${WRAPPER_NAME}

echo "Ensuring directories exist..."
mkdir -p "${FW_DST_DIR}"
echo "Removing ${FW_DST_DIR}/${MY_FW} ..."
rm -rf "${FW_DST_DIR}/${MY_FW}"
echo "Copying ${BUILT_PRODUCTS_DIR}/${MY_FW} to ${FW_DST_DIR} ..."
mkdir "${FW_DST_DIR}/${MY_FW}"
cp -R "${BUILT_PRODUCTS_DIR}/${MY_FW}"/* "${FW_DST_DIR}/${MY_FW}"/

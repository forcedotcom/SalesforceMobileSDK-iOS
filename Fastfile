lane :CI do
  scan(
  	workspace: "SalesforceMobileSDK-iOS/SalesforceMobileSDK.xcworkspace",
  	scheme: "UnitTests",
    device: "iPhone 6",
  	clean: true
  )
  xcov(
    workspace: "SalesforceMobileSDK-iOS/SalesforceMobileSDK.xcworkspace",
  	scheme: "UnitTests",
  	output_directory: "xcov_output"
  )
  danger(
  	danger_id: "unit-tests",
  	dangerfile: "SalesforceMobileSDK-iOS/DangerFile",
  	github_api_token: ENV["DANGER_GITHUB_API_TOKEN"],
  	verbose: true
  )
end

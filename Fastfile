lane :CI do

	begin
		scan(
			workspace: "SalesforceMobileSDK-iOS/SalesforceMobileSDK.xcworkspace",
			scheme: "UnitTests",
	    	device: "iPhone 6",
			xcargs: "analyze",
			output_directory: "SalesforceMobileSDK-iOS/test_output”,
	  		clean: true
	   	)
	rescue => ex
		UI.error(ex)
	end
 
	begin
		xcov(
			workspace: "SalesforceMobileSDK-iOS/SalesforceMobileSDK.xcworkspace",
	  		scheme: "UnitTests",
	  		output_directory: "SalesforceMobileSDK-iOS/xcov_output"
	  	)
	rescue => ex
	  	UI.error(ex)
	end

	begin
	   	danger(
	  		danger_id: "unit-tests",
	  		dangerfile: "SalesforceMobileSDK-iOS/DangerFile",
	  		github_api_token: ENV["DANGER_GITHUB_API_TOKEN"],
	  		verbose: true
	  	)
	rescue => ex
	   	UI.error(ex)
	end

end

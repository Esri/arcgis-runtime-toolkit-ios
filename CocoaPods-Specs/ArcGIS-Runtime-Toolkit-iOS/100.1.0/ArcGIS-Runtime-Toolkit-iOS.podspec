Pod::Spec.new do |s|
  s.platform     			= :ios
  s.name         			= "ArcGIS-Runtime-Toolkit-iOS"
  s.ios.deployment_target 	= "9.0"
  s.summary             	= "Toolkit components that will simplify iOS app development with ArcGIS Runtime SDK for iOS"
  s.homepage				= "https://developers.arcgis.com/en/ios/"
  s.author       			= { 'Esri' => 'iOSDevelopmentTeam@esri.com' }
  s.version  	    		= "100.1.0"
  s.dependency       		'ArcGIS-Runtime-SDK-iOS', '~> 100.1.0'
  s.source 					= { :git => 'https://github.com/Esri/arcgis-runtime-toolkit-ios.git', :tag => "v#{s.version}" }
  s.source_files 			= 'Toolkit/ArcGISToolkit/*.swift'
  s.module_name             = 'ArcGISToolkit'
  s.license      			= { :type => 'Apache License, Version 2.0' }
  s.description				= "Toolkit components for commonly used functionality that will simplify iOS app development with ArcGIS Runtime SDK for iOS"
end

# arcgis-runtime-toolkit-ios
Toolkit components that will simplify your iOS app development with ArcGIS Runtime. Check out the [Examples](/Examples) project to see these components in action or read through the [Documentation](/Documentation) to learn more about them.


## Toolkit Components

* [Scalebar](Documentation/Scalebar)
* Legend

## Requirements
* [ArcGIS Runtime SDK for iOS](https://developers.arcgis.com/en/ios/) 100.1 (or higher)
* Xcode 8 (or higher)
* Apple iOS SDK 10 (or higher)

## Instructions

#### Manual
 1. Ensure you have downloaded and installed __ArcGIS Runtime SDK for iOS__ as described [here](https://developers.arcgis.com/ios/latest/swift/guide/install.htm#ESRI_SECTION1_D57435A2BEBC4D29AFA3A4CAA722506A)
 2. Clone or download this repo. 
 3. Drag and Drop the `Toolkit/ArcGISToolkit.xcodeproj` file into your project through the XCode Project Navigator pane.
 4. Add `import ArcGISToolit` in your source code and start using the toolkit components 

<!--
//Can't get cocopoads to work because a dynamic framework (toolkit) cannot have a dependency on a static framework (sdk cocopad). Need to figure out how to deliver sdk as dynamic framework cocoapod

#### Cocoapods
 1. Add `pod ArcGIS-Runtime-SDK-iOS-Toolkit` to your podfile
 2. Run `pod install`. This will install the toolkit and also the ArcGIS Runtime SDK for iOS which the toolkit depends upon.	
 3. Add `import ArcGISToolit` in your source code and start using the toolkit components 

 New to cocoapods? Visit [cocoapods.org](https://cocoapods.org/)
 -->

## Additional Resources

* New to ArcGIS Runtime? Explore the documentation : [Guide](https://developers.arcgis.com/ios) | [API Reference](https://developers.arcgis.com/ios/latest/api-reference/), and check out the [Samples](https://github.com/Esri/arcgis-runtime-samples-ios)
* Got a question? Ask the community on our [forum](http://geonet.esri.com/community/developers/native-app-developers/arcgis-runtime-sdk-for-ios)

## Issues

Find a bug or want to request a new feature?  Please let us know by submitting an issue.

## Contributing

Esri welcomes contributions from anyone and everyone. Please see our [guidelines for contributing](https://github.com/esri/contributing).

## Licensing
Copyright 2017 Esri

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

A copy of the license is available in the repository's [LICENSE]( https://github.com/Esri/arcgis-runtime-toolkit-ios/blob/master/LICENSE) file.


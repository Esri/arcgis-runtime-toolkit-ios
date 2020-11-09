# ArcGIS Runtime Toolkit for iOS

[![doc](https://img.shields.io/badge/Doc-purple)](Documentation) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![CocoaPods](https://img.shields.io/cocoapods/v/ArcGIS-Runtime-Toolkit-iOS)](https://cocoapods.org/)

The ArcGIS Runtime SDK for iOS Toolkit contains components that will simplify your iOS app development. Check out the [Examples](/Examples) project to see these components in action or read through the [Documentation](/Documentation) to learn more about them.

To use Toolkit in your project:

* **[Install with CocoaPods](#cocoapods)** - Add `pod 'ArcGIS-Runtime-Toolkit-iOS'` to your podfile
* **[Install with Carthage](#carthage)** - Add `github "esri/arcgis-runtime-toolkit-ios"` to your cartfile
* **[Build manually](#manual)** - Build and include manually if you'd like to customize or extend toolkit

## Toolkit Components

* **[Augmented reality (AR)](Documentation/AR)** - Integrates the scene view with ARKit to enable augmented reality (AR).
* **[Bookmarks](Documentation/Bookmarks)** - Shows bookmarks, from a map, scene, or a list.
* **[Compass](Documentation/Compass)** - Shows a compass direction when the map is rotated. Auto-hides when the map points north up.
* **[JobManager](Documentation/JobManager)** - Suspends and resumes ArcGIS Runtime tasks when the app is background, terminated, and relaunched.
* **[LegendViewController](Documentation/LegendViewController)** - Displays a legend for all the layers in a map or scene contained in an `AGSGeoView`.
* **[MeasureToolbar](Documentation/MeasureToolbar)** - Allows measurement of distances and areas on the map view.
* **[PopupController](Documentation/PopupController)** - Display details and media, edit attributes, geometry and related records, and manage the attachments of features and graphics (popups are defined in the popup property of features and graphics).
* **[Scalebar](Documentation/Scalebar)** - Displays current scale reference.
* **[TemplatePickerViewController](Documentation/TemplatePicker)** - Allows a user to choose a template from a list of `AGSFeatureTemplate` when creating new features.
* **[TimeSlider](Documentation/TimeSlider)** - Allows interactively defining a temporal range (i.e. time extent) and animating time moving forward or backward. Can be used to manipulate the time extent in a MapView or SceneView.

## Requirements
* [ArcGIS Runtime SDK for iOS](https://developers.arcgis.com/en/ios/) 100.9.0 (or higher)
* Xcode 11.0 (or higher)

The *ArcGIS Runtime Toolkit for iOS* has a *Target SDK* version of *12.0*, meaning that it can run on devices with *iOS 12.0* or newer.

## Instructions

### Cocoapods

 1. Add `pod 'ArcGIS-Runtime-Toolkit-iOS'` to your podfile
 2. Run `pod install`. This will download the toolkit and the ArcGIS Runtime SDK for iOS which the toolkit depends upon and then configure your project to reference them both.	
 3. Add `import ArcGISToolkit` in your source code and start using the toolkit components 

 New to cocoapods? Visit [cocoapods.org](https://cocoapods.org/)

### Carthage

Carthage is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

 1. Add `github "esri/arcgis-runtime-toolkit-ios"` to your Cartfile
 2. Run `carthage update`
 3. Drag the `ArcGISToolkit.framework ` from the `Carthage/Build ` folder to the "TARGETS" settings for your application and drop it in the "Embedded Binaries" section in the "General" tab
 4. Add `import ArcGISToolkit` in your source code and start using the toolkit components 

New to Carthage? Visit the Carthage [GitHub](https://github.com/Carthage/Carthage) page.

Note that you must also have the __ArcGIS Runtime SDK for iOS__ installed and your project set up as per the instructions [here](https://developers.arcgis.com/ios/latest/swift/guide/install.htm#ESRI_SECTION1_D57435A2BEBC4D29AFA3A4CAA722506A).

### Manual

 1. Ensure you have downloaded and installed __ArcGIS Runtime SDK for iOS__ as described [here](https://developers.arcgis.com/ios/latest/swift/guide/install.htm#ESRI_SECTION1_D57435A2BEBC4D29AFA3A4CAA722506A)
 2. Clone or download this repo. 
 3. Drag and Drop the `Toolkit/ArcGISToolkit.xcodeproj` file into your project through the XCode Project Navigator pane.
 4. Drag the `ArcGISToolkit.framework` from the `ArcGISToolkit.xcodeproj/ArcGISToolkit/Products` folder to the "TARGETS" settings for your application and drop it in the "Embedded Binaries" section in the "General" tab
 5. Add `import ArcGISToolkit` in your source code and start using the toolkit components 

## SwiftLint

Both the Toolkit and Examples app support SwiftLint.  You can install SwiftLint from [here](https://github.com/realm/SwiftLint).  It is not necessary to have it installed in order to build, but you will get a warning without it.  The specific rules the linter uses can be found in the `swiftlint.yml` files in the `Toolkit` and `Examples` directories.

## Additional Resources

* [Developers guide documentation](https://developers.arcgis.com/ios)
* [Runtime API Reference](https://developers.arcgis.com/ios/latest/api-reference/)
* [Samples](https://github.com/Esri/arcgis-runtime-samples-ios)
* Got a question? Ask the community on our [forum](http://geonet.esri.com/community/developers/native-app-developers/arcgis-runtime-sdk-for-ios)

## Issues

Find a bug or want to request a new feature?  Please let us know by [submitting an issue](https://github.com/Esri/arcgis-runtime-toolkit-ios/issues/new).

## Contributing

Esri welcomes contributions from anyone and everyone. Please see our [guidelines for contributing](https://github.com/esri/contributing).

## Licensing
Copyright 2017 - 2020 Esri

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

A copy of the license is available in the repository's [LICENSE]( /LICENSE) file.

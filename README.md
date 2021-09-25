# ArcGIS Runtime Toolkit for iOS

[![doc](https://img.shields.io/badge/Doc-purple)](Documentation)
[![CocoaPods](https://img.shields.io/cocoapods/v/ArcGIS-Runtime-Toolkit-iOS)](https://cocoapods.org/)
[![SPM](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://github.com/apple/swift-package-manager/)

The ArcGIS Runtime SDK for iOS Toolkit contains components that will simplify your iOS app development. Check out the
[Examples](/Examples) project to see these components in action or read through the [Documentation](/Documentation) to
learn more about them.

To use Toolkit in your project:

* **[Install with CocoaPods](#cocoapods)** - Add `pod 'ArcGIS-Runtime-Toolkit-iOS'` to your podfile
* **[Install with Swift Package Manager](#swift-package-manager)** - Add
  `https://github.com/Esri/arcgis-runtime-toolkit-ios` as the package repository URL.
* **[Build manually](#manual)** - Build and include manually if you'd like to customize or extend toolkit

## Toolkit Components

* **[Augmented reality (AR)](Documentation/AR)** - Integrates the scene view with ARKit to enable augmented reality
  (AR).
* **[Bookmarks](Documentation/Bookmarks)** - Shows bookmarks, from a map, scene, or a list.
* **[Compass](Documentation/Compass)** - Shows a compass direction when the map is rotated. Auto-hides when the map
  points north up.
* **[JobManager](Documentation/JobManager)** - Suspends and resumes ArcGIS Runtime tasks when the app is background,
  terminated, and relaunched.
* **[LegendViewController](Documentation/LegendViewController)** - Displays a legend for all the layers in a map or
  scene contained in an `AGSGeoView`.
* **[MeasureToolbar](Documentation/MeasureToolbar)** - Allows measurement of distances and areas on the map view.
* **[PopupController](Documentation/PopupController)** - Display details and media, edit attributes, geometry and
  related records, and manage the attachments of features and graphics (popups are defined in the popup property of
  features and graphics).
* **[Scalebar](Documentation/Scalebar)** - Displays current scale reference.
* **[TemplatePickerViewController](Documentation/TemplatePicker)** - Allows a user to choose a template from a list of
  `AGSFeatureTemplate` when creating new features.
* **[TimeSlider](Documentation/TimeSlider)** - Allows interactively defining a temporal range (i.e. time extent) and
  animating time moving forward or backward. Can be used to manipulate the time extent in a MapView or SceneView.

## Requirements

* [ArcGIS Runtime SDK for iOS](https://developers.arcgis.com/ios/) 100.12.0 (or higher)
* Xcode 12.0 (or higher)

The *ArcGIS Runtime Toolkit for iOS* has a *Target SDK* version of *13.0*, meaning that it can run on devices with *iOS
13.0* or newer.

## Instructions

### Swift Package Manager

 1. Open your project in Xcode
 2. Go to *File* > *Swift Packages* > *Add Package Dependency* option
 3. Enter `https://github.com/Esri/arcgis-runtime-toolkit-ios` as the package repository URL
 4. Choose version 100.12.0 or a later version. Click Next. Only version 100.11.0 or newer supports Swift Package
    Manager.

 Note: The Toolkit Swift Package adds the ArcGIS SDK Swift Package as a dependency so no need to add both separately. If
 you already have the ArcGIS SDK Swift Package delete that and just add the Toolkit Swift Package.

 New to Swift Package Manager? Visit [swift.org/package-manager/](https://swift.org/package-manager/).

### Cocoapods

 1. Add `pod 'ArcGIS-Runtime-Toolkit-iOS'` to your podfile
 2. Run `pod install`. This will download the toolkit and the ArcGIS Runtime SDK for iOS which the toolkit depends upon
    and then configure your project to reference them both
 3. Add `import ArcGISToolkit` in your source code and start using the toolkit components

 New to cocoapods? Visit [cocoapods.org](https://cocoapods.org/)

### Manual

 1. Clone or download this repo
 2. Drag and Drop the `arcgis-runtime-toolkit-ios` folder into your project through the Xcode Project Navigator pane
 3. Add the *ArcGISToolkit* library in your app, by adding it to the Frameworks, Libraries, and Embedded Content section
    of the General pane for your app target. The *ArcGISToolkit* library contains the *ArcGIS Runtime SDK for iOS*
    library, so you don't need to add that separately.
 4. Add `import ArcGIS` and `import ArcGISToolkit` in your source code and start using the toolkit components

Note: The manual installation method also allows you to use a local installation ArcGIS Runtime SDK for iOS by making
minor edits to the [swift package](Package.swift).

## SwiftLint

Both the Toolkit and Examples app support SwiftLint.  You can install SwiftLint from
[here](https://github.com/realm/SwiftLint).  It is not necessary to have it installed in order to build, but you will
get a warning without it.  The specific rules the linter uses can be found in the `swiftlint.yml` files in the `Toolkit`
and `Examples` directories.

## Additional Resources

* [Developers guide documentation](https://developers.arcgis.com/ios)
* [Runtime API Reference](https://developers.arcgis.com/ios/api-reference)
* [Samples](https://github.com/Esri/arcgis-runtime-samples-ios)
* Got a question? Ask the community on our
  [forum](http://geonet.esri.com/community/developers/native-app-developers/arcgis-runtime-sdk-for-ios)

## Issues

Find a bug or want to request a new feature?  Please let us know by [submitting an
issue](https://github.com/Esri/arcgis-runtime-toolkit-ios/issues/new).

## Contributing

Esri welcomes contributions from anyone and everyone. Please see our [guidelines for
contributing](https://github.com/esri/contributing).

## Licensing

Copyright 2017 - 2021 Esri

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at

   <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific
language governing permissions and limitations under the License.

A copy of the license is available in the repository's [LICENSE]( /LICENSE) file.

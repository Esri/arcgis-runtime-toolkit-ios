# Augmented reality (AR)

[![guide doc](https://img.shields.io/badge/Full_Developers_Guide-Doc-purple)](https://developers.arcgis.com/ios/scenes-3d/display-scenes-in-augmented-reality/) [![world-scale sample](https://img.shields.io/badge/World_Scale-Sample-blue)](https://developers.arcgis.com/ios/swift/sample-code/collect-data-in-ar/) [![Tabletop sample](https://img.shields.io/badge/Tabletop-Sample-blue)](https://developers.arcgis.com/ios/swift/sample-code/display-scenes-in-tabletop-ar/) [![Flyover sample](https://img.shields.io/badge/Flyover-Sample-blue)](https://developers.arcgis.com/ios/swift/sample-code/explore-scenes-in-flyover-ar/)

Augmented reality experiences are designed to "augment" the physical world with virtual content that respects real world scale, position, and orientation of a device. In the case of Runtime, a SceneView displays 3D geographic data as virtual content on top of a camera feed which represents the real, physical world.

The Augmented Reality (AR) toolkit component allows quick and easy integration of AR into your application for a wide variety of scenarios.  The toolkit recognizes the following common patterns for AR: 
* **Flyover**: Flyover AR allows you to explore a scene using your device as a window into the virtual world. A typical flyover AR scenario will start with the scene’s virtual camera positioned over an area of interest. You can walk around and reorient the device to focus on specific content in the scene. 
* **Tabletop**: Scene content is anchored to a physical surface, as if it were a 3D-printed model. 
* **World-scale**: Scene content is rendered exactly where it would be in the physical world. A camera feed is shown and GIS content is rendered on top of that feed. This is used in scenarios ranging from viewing hidden infrastructure to displaying waypoints for navigation.

The AR toolkit component is comprised of one class: `ArcGISARView`.  This is a subclass of `UIView` that contains the functionality needed to display an AR experience in your application.  It uses `ARKit`, Apple's augmented reality framework to display the live camera feed and handle real world tracking and synchronization with the Runtime SDK's `AGSSceneView`.  The `ArcGISARView` is responsible for starting and managing an `ARKit` session.  It uses a user-provided `AGSLocationDataSource` for getting an initial GPS location and when continuous GPS tracking is required.

### Features of the AR component

- Allows display of the live camera feed
- Manages `ARKit` `ARSession` lifecycle
- Tracks user location and device orientation through a combination of `ARKit` and the device GPS
- Provides access to an `AGSSceneView` to display your GIS 3D data over the live camera feed
- `ARScreenToLocation` method to convert a screen point to a real-world coordinate
- Easy access to all `ARKit` and `AGSLocationDataSource` delegate methods

### Usage

```swift
let arView = ArcGISARView(renderVideoFeed: true)
view.addSubview(arView)
arView.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    arView.topAnchor.constraint(equalTo: view.topAnchor),
    arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])


// Create a simple scene.
arView.sceneView.scene = AGSScene(basemapType: .imagery)

// Set a AGSCLLocationDataSource, used to get our initial real-world location.
arView.locationDataSource = AGSCLLocationDataSource()

// Start tracking our location and device orientation
arView.startTracking(.initial) { (error) in
    print("Start tracking error: \(String(describing: error))")
}

```

You must also add the following entries to your application's `Info.plist` file.  These are required to allow access to the camera (for the live video feed) and to allow access to location services (when using the `AGSCLLocationDataSource`):

* Privacy – Camera Usage Description ([NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nscamerausagedescription))
* Privacy – Location When In Use Usage Description ([NSLocationWhenInUseUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocationwheninuseusagedescription))

To see it in action, try out the [Examples](../../Examples) and refer to [ARExample.swift](../../Examples/ArcGISToolkitExamples/ARExample.swift) in the project.

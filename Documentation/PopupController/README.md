# PopupController

The PopupController makes it easy to wire up an `AGSPopupsViewController` for a complete feature editing and collecting experience. To use it, you instantiate the `PopupController` and hold on to it. You must pass it a reference to your `UIViewController` and to your `AGSGeoView`. 

### Usage

```swift
var popupController : PopupController?

override func viewDidLoad() {
    super.viewDidLoad()

    // Creat a map
    portalItem = AGSPortalItem(portal: portal, itemID: "<<Portal Item ID Goes Here>>")
    map = AGSMap(item: portalItem!)

    // set the map on the mapview
    mapView.map = map

    // instantiate the popup controller
    popupController = PopupController(geoViewController: self, geoView: mapView)
}
```

To see it in action, try out the [Examples](../../Examples) and refer to [PopupExample.swift](../../Examples/ArcGISToolkitExamples/PopupExample.swift) in the project.





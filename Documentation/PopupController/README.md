# PopupController

The PopupController makes it easy to wire up an `AGSPopupsViewController` for a complete feature editing and collecting experience. To use it, you instantiate the `PopupController` and hold on to it. You must pass it a reference to your `UIViewController` and to your `AGSGeoView`. 

### Usage

```swift
var popupController: PopupController?

override func viewDidLoad() {
    super.viewDidLoad()

    // Create a map        
    let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
    let portalItem = AGSPortalItem(portal: portal, itemID: "<<YOUR PORTAL ITEM ID GOES HERE>>")!
    map = AGSMap(item: portalItem)

    // set the map on the mapview
    mapView.map = map

    // instantiate the popup controller
    popupController = PopupController(geoViewController: self, geoView: mapView)
}
```

Note: Make sure to add `Privacy - Photo Library Usage Description`, `Privacy - Microphone Usage Description`, and `Privacy - Camera Usage Description` to your project's `Info.plist` to correctly add attachments. 

To see it in action, try out the [Examples](../../Examples) and refer to [PopupExample.swift](../../Examples/ArcGISToolkitExamples/PopupExample.swift) in the project.





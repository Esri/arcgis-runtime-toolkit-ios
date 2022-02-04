#  FloorFilter

The `FloorFilter` component simplifies visualization of GIS data for a specific floor of a building in your application. It allows you to filter down the floor plan data displayed in your geo view to a site, a building in the site, or a floor in the building. 

The ArcGIS Runtime SDK currently supports filtering a 2D floor aware map based on the sites, buildings, or levels in the map.

###Behavior:

When the Site button is tapped, a prompt opens so the user can select a site and then a facility. After selecting a site and facility, a list of levels is displayed either above or below the site button.

### Usage

```swift

addChild(floorFilterViewController)
view.addSubview(floorFilterViewController.view)
floorFilterViewController.didMove(toParent: self)

```

To see it in action, try out the [Examples](../../Examples) and refer to [FloorFilterExample.swift](../../Examples/ArcGISToolkitExamples/FloorFilterExample.swift) in the project.

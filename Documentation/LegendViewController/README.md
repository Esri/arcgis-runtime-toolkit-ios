# Legend View Controller

A Legend View Controller displays a legend for a set of layers in a Map or Scene contained in a MapView or SceneView. A legend conveys the meaning of the symbols used to represent features in the layer. For each layer, the legend contains a patch displaying the symbology used along with some explanatory text. The Legend View Controller is dynamic and only contains information about visible layers. As layers go in and out of scale range, or are turned on/off, the legend updates to include only those layers that are visible to the user in the MapView or SceneView.
 


### Usage

```swift

	let legendVC = LegendViewController.makeLegendViewController(geoView: mapView)
	self.present(legendVC,  animated:true, completion:nil)
		
```

To see it in action, try out the [Examples](../../Examples) and refer to [LegendExample.swift](../../Examples/ArcGISToolkitExamples/LegendExample.swift) in the project.





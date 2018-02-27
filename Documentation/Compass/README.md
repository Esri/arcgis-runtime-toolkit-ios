# Compass

The Compass (alias North arrow) shows where north is in the MapView. The Compass supports reset rotation.

The ArcGIS Runtime SDK currently supports rotating the map with 2-finger gesture on MapView and SceneView interactively by default and while the map will snap to north when rotating using gestures, the compass provides an easier way. The Compass Toolkit component will appear when the map is rotated and, when tapped, re-orientates the map back to north and hides the compass icon (note that the MapView auto-snaps back to north when it's within a threshold of north, and in that case the compass also auto hides).

### Compass Behavior:

Whenever the map is not orientated North (non-zero bearing) the compass appears. When reset to north, it disappears. A property allows you to disable the auto-hide feature so that it always shows.

When the compass is tapped, the map orients back to north (zero bearing), the default orientation and the compass fades away, or after a short duration disappears.

### Usage

```swift

        let compass = Compass(mapView: mapView)
        self.view.addSubview(compass)
```

To see it in action, try out the [Examples](../../Examples) and refer to [CompassExample.swift](../../Examples/ArcGISToolkitExamples/CompassExample.swift) in the project.





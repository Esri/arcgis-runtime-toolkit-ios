# Scalebar

A scalebar displays the representation of an accurate linear measurement on the map. It provides a visual indication through which users can determine the size of features or the distance between features on a map. A scale bar is a line or bar divided into parts. It is labeled with its ground length, usually in multiples of map units, such as tens of kilometers or hundreds of miles. 

The scalebar uses geodetic calculations to provide accurate results for maps of any spatial reference. The measurement it displays is accurate for the center of the map. This means at smaller scales (zoomed way out) you might find it somewhat inaccurate at the extremes of the visible extent. As the map is panned and zoomed, the scalebar automatically grows and shrinks and updates its measurement based on the new map extent.

### Usage


### Styles


|-------------|--------|
|  line |  ![line](Images/line.png) |
|	graduated line|	![graduated line](Images/graduated-line.png)|
|	bar |![bar](Images/bar.png)	|
|	alternating bar|	![alternating bar](Images/alternating-bar.png) |
|	dual unit line|	![dual unit line](Images/dual-unit-line.png) |



### Units

Two options are available - `metric` and `imperial`. Defaults to the option most appropriate for the device locale. `metric` displays distances in meters and kilometers depending on the map scale, and `imperial` displays distances in feet and miles.


### Customization

You can customize many visual elements of the scalebar such as - 

* `fillColor`
* `alternateFillColor`
* `lineColor`
* `shadowColor`
* `textColor`
* `textShadowColor`
* `font`


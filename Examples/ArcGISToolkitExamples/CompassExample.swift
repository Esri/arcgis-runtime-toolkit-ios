// Copyright 2017 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGISToolkit
import ArcGIS

class CompassExample: MapViewController {
    var map: AGSMap?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize an AGSMap with the Modern Antique basemap and center it on South America.
        map = AGSMap(basemapStyle: .arcGISModernAntique)
        map?.initialViewpoint = AGSViewpoint(latitude: -25, longitude: -56, scale: 6e7)
        mapView.map = map
        
        // Create the compass and add it to our view.
        let compass = Compass(mapView: mapView)
        compass.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(compass)
        
        // Get the superview's layout.
        let margins = view.layoutMarginsGuide

        // Position the compass in the top right corner using auto layout constraints.
        // The Compass handles width/height constraints, so we don't need to do that here.
        compass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12.0).isActive = true
        compass.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
    }
}

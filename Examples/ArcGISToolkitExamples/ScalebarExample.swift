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

class ScalebarExample: MapViewController, AGSGeoViewTouchDelegate {
    var map: AGSMap?
    var scalebar: Scalebar?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        map = AGSMap(basemapStyle: .arcGISTopographic)
        mapView.map = map
        
        let width = CGFloat(175)
        let xMargin = CGFloat(10)
        let yMargin = CGFloat(10)
        
        // lower left scalebar
        let sb = Scalebar(mapView: mapView)
        sb.units = .metric
        sb.alignment = .left
        sb.style = .alternatingBar
        view.addSubview(sb)
        
        // add constraints so it's anchored to lower left corner
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.widthAnchor.constraint(equalToConstant: width).isActive = true
        sb.bottomAnchor.constraint(equalTo: mapView.attributionTopAnchor, constant: -yMargin).isActive = true
        sb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: xMargin).isActive = true
        scalebar = sb
    }
}

//
// Copyright 2021 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit
import ArcGIS
import ArcGISToolkit

class FloorFilterExample: MapViewController {
    var floorFilterVC: FloorFilterViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the map from a portal item and assign to the mapView.
        let portal = AGSPortal(url: URL(string: "https://indoors.maps.arcgis.com/")!, loginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "f133a698536f44c8884ad81f80b6cfc7")
        let map = AGSMap(item: portalItem)
        mapView.map = map
        
        self.floorFilterVC = FloorFilterViewController.makeFloorFilterView(
            geoView: mapView,
            buttonWidth: 50,
            buttonHeight: 50
        )
        
        let xMargin = CGFloat(10)
        let yMargin = CGFloat(30)
        let width = CGFloat(50)
        
        if let floorFilterVC = self.floorFilterVC {
            floorFilterVC.onSelectedLevelChangedListener = {
                print("Level was changed")
            }
            // Add floor filter to the current view
            self.view.addSubview(floorFilterVC.view)
            floorFilterVC.view.translatesAutoresizingMaskIntoConstraints = false
            floorFilterVC.view.widthAnchor.constraint(equalToConstant: width).isActive = true
            floorFilterVC.view.bottomAnchor.constraint(equalTo: mapView.attributionTopAnchor, constant: -yMargin).isActive = true
            floorFilterVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: xMargin).isActive = true
        
        }
    }
}

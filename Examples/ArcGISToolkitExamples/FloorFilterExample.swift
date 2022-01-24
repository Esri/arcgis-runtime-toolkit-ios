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
        
        let leadingConstraint = CGFloat(40)
        
        // The style of the floor filter determines which way it will open. If the floor filter is placed on the top of the screen, it is recommended to use the style 'expandDown'.
        // If floor filter placed on the bottom of the screen, then use 'expandUp'
        floorFilterVC = FloorFilterViewController.makeFloorFilterView(
            geoView: mapView,
            buttonWidth: 50,
            buttonHeight: 50,
            maxDisplayLevels: 3,
            style: .expandDown
        )
        if let floorFilterVC = self.floorFilterVC {
            floorFilterVC.onSelectedLevelChangedListener = {
                print("Level was changed")
            }
            
            // Add floor filter to the current view
            floorFilterVC.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(floorFilterVC.view)
    
            floorFilterVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingConstraint).isActive = true


            // This places the floor filter at the top of the view,
            // just below the top anchor of the safe area layout guide.
            floorFilterVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: leadingConstraint).isActive = true

            // This places the floor filter at the bottom of the view,
            // anchored to the top of the map view's attribution bar.
//            floorFilterVC.view.bottomAnchor.constraint(equalTo: mapView.attributionTopAnchor, constant: -leadingConstraint).isActive = true
        }
    }
}

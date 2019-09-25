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

class LegendExample: MapViewController {
    let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
    var portalItem: AGSPortalItem?
    var map: AGSMap?
    var legendVC: LegendViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create and set map on mapView
        portalItem = AGSPortalItem(portal: portal, itemID: "1966ef409a344d089b001df85332608f")
        map = AGSMap(item: portalItem!)
        mapView.map = map
        
        legendVC = LegendViewController.makeLegendViewController(geoView: mapView)
        
        // add button that will show the SwitchBasemapViewController
        let bbi = UIBarButtonItem(title: "Legend", style: .plain, target: self, action: #selector(showLegendAction))
        navigationItem.rightBarButtonItem = bbi
    }
    
    @objc
    func showLegendAction() {
        if let legendVC = legendVC {
            navigationController?.pushViewController(legendVC, animated: true)
        }
    }
}

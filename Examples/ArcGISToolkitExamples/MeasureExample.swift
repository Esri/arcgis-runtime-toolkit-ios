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

class MeasureExample: MapViewController{
    
    var measureToolbar : MeasureToolbar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set a map on our mapView
        let portalItem = AGSPortalItem(portal: AGSPortal.arcGISOnline(withLoginRequired: false), itemID: "32eb38c48f91421a96e64fe1af492030")
        let map = AGSMap(item: portalItem)
        mapView.map = map
        
        // create a MeasureToolbar and add it to the view controller
        measureToolbar = MeasureToolbar(mapView: mapView)
        measureToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(measureToolbar)
        measureToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        measureToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        measureToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//        if #available(iOS 11.0, *) {
//            measureToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
//        } else {
//        }

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // update content inset for mapview
        let tbHeight = measureToolbar.frame.height
        
        if #available(iOS 11.0, *) {
            mapView.contentInset = UIEdgeInsetsMake(0, 0, view.safeAreaInsets.bottom + tbHeight, 0)
        }
        else{
            mapView.contentInset = UIEdgeInsetsMake(0, 0, tbHeight, 0)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

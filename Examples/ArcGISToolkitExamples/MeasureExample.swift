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

class MeasureExample: MapViewController {
    
    var measureToolbar : MeasureToolbar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set a map on our mapView
        let portalItem = AGSPortalItem(portal: AGSPortal.arcGISOnline(withLoginRequired: false), itemID: "32eb38c48f91421a96e64fe1af492030")
        let map = AGSMap(item: portalItem)
        mapView.map = map
        
        let toolbarFrame = CGRect(x: 0, y: view.bounds.size.height - 44.0, width: view.bounds.size.width, height: 44.0)
        
        // create a MeasureToolbar and add it to the view controller
        measureToolbar = MeasureToolbar(mapView: mapView)
        measureToolbar.frame = toolbarFrame
        measureToolbar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(measureToolbar)

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

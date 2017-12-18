// Copyright 2016 Esri.

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

class SwitchBasemapExample: MapViewController {
    
    let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
    var portalItem : AGSPortalItem?
    var map : AGSMap?
    var switchBasemapVC : SwitchBasemapViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // open a map
        portalItem = AGSPortalItem(portal: portal, itemID: "22839dfed86f42b6ac0f7bea9677ee07")
        map = AGSMap(item: portalItem!)
        mapView.map = map
        
        // create SwitchBasemapViewController
        switchBasemapVC = SwitchBasemapViewController(map: map!)
        
        // add button that will show the SwitchBasemapViewController
        let bbi = UIBarButtonItem(title: "Basemap", style: .plain, target: self, action: #selector(switchBasemapAction))
        navigationItem.rightBarButtonItem = bbi
    }
    
    func switchBasemapAction(){
        if let switchBasemapVC = switchBasemapVC{
            navigationController?.pushViewController(switchBasemapVC, animated: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

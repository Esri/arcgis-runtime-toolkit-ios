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

class PopupExample: MapViewController {
    var map: AGSMap?
    
    var popupController: PopupController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a map
        map = AGSMap(basemapStyle: .arcGISTopographic)
        let featureTable = AGSServiceFeatureTable(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!)
        let featureLayer = AGSFeatureLayer(featureTable: featureTable)
        map?.operationalLayers.add(featureLayer)

        // Here we give the feature layer a default popup definition.
        // We have to load it first to create a default popup definition.
        // If you create the map from a portal item, you can define the popup definition
        // in the webmap and avoid this step.
        featureLayer.load { _ in
            featureLayer.popupDefinition = AGSPopupDefinition(popupSource: featureLayer)
        }
        
        // Another way to create the map is with a portal item:
        // let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        // let portalItem = AGSPortalItem(portal: portal, itemID: "<<YOUR PORTAL ITEM ID GOES HERE>>")!
        // map = AGSMap(item: portalItem)
        
        // set the map on the mapview
        mapView.map = map
        
        // Log if there is any error loading the map
        map?.load { error in
            if let error = error {
                print("error loading map: \(error)")
            }
        }
        
        // instantiate the popup controller
        popupController = PopupController(geoViewController: self, geoView: mapView)
    }
}

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
    
    let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
    var portalItem : AGSPortalItem?
    var map : AGSMap?
    
    var popupController : PopupController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Creat a map
        
        // create a map
        map = AGSMap(basemap: .topographic())
        let featureTable = AGSServiceFeatureTable(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!)
        let featureLayer = AGSFeatureLayer(featureTable: featureTable)
        map?.operationalLayers.add(featureLayer)

        // Here we give the feature layer a default popup definition.
        // We have to load it first to create a default popup definition.
        // If you create the map from a portal item, you can define the popup definition
        // in the webmap.
        featureLayer.load{ _ in
            featureLayer.popupDefinition = AGSPopupDefinition(popupSource: featureLayer)
        }
        
        // Another way to create the map is with a portal item:
        //portalItem = AGSPortalItem(portal: portal, itemID: "cebba45198704f89a9292af0bb1ec0fc")
        //portalItem = AGSPortalItem(portal: portal, itemID: "655a67d60432459eb5a2b253caa87892")
        
//        portalItem = AGSPortalItem(portal: portal, itemID: "b31153c71c6c429a8b24c1751a50d3ad")
//        map = AGSMap(item: portalItem!)
//
//        map?.load{ error in
//            if let error = error{
//                print("error loading map: \(error)")
//            }
//
////            AGSLoadObjects(self.map?.operationalLayers as! [AGSLayer]){ success in
////                for l in (self.map?.operationalLayers as! [AGSLayer]){
////                    if let ps = l as? AGSPopupSource{
////                        if ps.popupDefinition == nil{
////                            ps.popupDefinition = AGSPopupDefinition(popupSource: ps)
////                            print("working...")
////                        }
////                    }
////                }
////                print("done...")
////            }
//
//
//        }
        
        // set the map on the mapview
        mapView.map = map
        
        // instantiate the popup controller
        popupController = PopupController(geoViewController: self, geoView: mapView)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}


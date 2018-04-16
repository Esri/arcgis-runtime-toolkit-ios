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

class SketchExample: MapViewController {
    
    var sketchToolbar : SketchToolbar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.map = AGSMap(basemapType: .topographic, latitude: 0, longitude: 0, levelOfDetail: 0)
        
        let toolbarFrame = CGRect(x: 0, y: view.bounds.size.height - 44.0, width: view.bounds.size.width, height: 44.0)
        
        // create a SketchToolbar and add it to the view controller
        sketchToolbar = SketchToolbar(mapView: mapView)
        sketchToolbar.frame = toolbarFrame
        sketchToolbar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(sketchToolbar)
        
        // know when geometry changes
        sketchToolbar.sketchEditorGeometryChangedHandler = {
            print("Geometry Changed")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

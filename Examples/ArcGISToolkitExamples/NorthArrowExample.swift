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

class NorthArrowExample: MapViewController {
    
    var map : AGSMap?
    
    var northArrow : NorthArrowController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize an AGSMap with the National Geographic basemap and center it on South America.
        map = AGSMap(basemapType: .nationalGeographic, latitude: -25, longitude: -56, levelOfDetail: 3)
        mapView.map = map
        
        // Load the compass image from the bundle.
        let arrowImage = UIImageView(image: UIImage(named: "CompassIcon"))

        self.view.addSubview(arrowImage)
        
        // Turn off the autoresize constraints so that auto layout constraints can be used.
        arrowImage.translatesAutoresizingMaskIntoConstraints = false
        
        // Get the superview's layout.
        let margins = view.layoutMarginsGuide
        
        // Position the north arrow image in the top right corner using auto layout constraints.
        arrowImage.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor, constant: 12.0).isActive = true
        arrowImage.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
        
        // add gesture recognizer to know when arrow is tapped
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(arrowTapped))
        arrowImage.addGestureRecognizer(tapGestureRecognizer)
        arrowImage.isUserInteractionEnabled = true
        
        // Initialize the NorthArrowController so the north arrow image will rotate to match the map rotation.
        northArrow = NorthArrowController(mapView: mapView, northArrowView: arrowImage)
    }

    func arrowTapped(){
        mapView.setViewpointRotation(0, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

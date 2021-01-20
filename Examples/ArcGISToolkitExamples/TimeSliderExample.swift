//
// Copyright 2018 Esri.

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

class TimeSliderExample: MapViewController {
    private var map = AGSMap(basemapStyle: .arcGISTopographic)
    private var timeSlider = TimeSlider()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set a map with ESRI topographic basemap to mapView
        mapView.map = map
        
        // Configure time slider
        timeSlider.isHidden = true
        timeSlider.labelMode = .ticks
        timeSlider.addTarget(self, action: #selector(TimeSliderExample.timeSliderValueChanged(timeSlider:)), for: .valueChanged)
        view.addSubview(timeSlider)
        
        //
        // Add constraints to position the slider
        let margin: CGFloat = 10.0
        timeSlider.translatesAutoresizingMaskIntoConstraints = false
        timeSlider.bottomAnchor.constraint(equalTo: mapView.attributionTopAnchor, constant: -margin).isActive = true
        timeSlider.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin).isActive = true
        timeSlider.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin).isActive = true
        
        // Add layer
        let mapImageLayer = AGSArcGISMapImageLayer(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/911CallsHotspot/MapServer")!)
        mapView.map?.operationalLayers.add(mapImageLayer)
        mapImageLayer.load { [weak self] (error) in
            // Make sure self is around
            guard let self = self else {
                return
            }
            
            // If layer fails to load then
            // return with an error.
            guard error == nil else {
                self.showError(error!)
                return
            }
            
            // Zoom to full extent of layer
            if let fullExtent = mapImageLayer.fullExtent {
                self.mapView.setViewpoint(AGSViewpoint(targetExtent: fullExtent), completion: nil)
            }
            
            self.timeSlider.initializeTimeProperties(geoView: self.mapView, observeGeoView: true) { [weak self] (error) in
                // Make sure self is around
                guard let self = self else {
                    return
                }
                
                // If time slider fails to init then
                // return with an error.
                guard error == nil else {
                    self.showError(error!)
                    return
                }
                
                // Show the time slider
                self.timeSlider.isHidden = false
            }
        }
    }
    
    @objc
    func timeSliderValueChanged(timeSlider: TimeSlider) {
        if mapView.timeExtent != timeSlider.currentExtent {
            mapView.timeExtent = timeSlider.currentExtent
        }
    }
    
    // MARK: - Show Error
    
    private func showError(_ error: Error) {
        let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }
}

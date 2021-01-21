// Copyright 2019 Esri.

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

class TemplatePickerExample: MapViewController {
    var map: AGSMap?
    
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
        
        // set the map on the mapview
        mapView.map = map
        
        // Log if there is any error loading the map
        map?.load { error in
            if let error = error {
                print("error loading map: \(error)")
            }
        }
        
        // add bar button item for showing templates
        let bbi = UIBarButtonItem(title: "Templates", style: .plain, target: self, action: #selector(showTemplates))
        navigationItem.rightBarButtonItem = bbi
    }
    
    @objc
    private func showTemplates() {
        guard let map = map else { return }
        
        // Instantiate the TemplatePickerViewController
        let templatePicker = TemplatePickerViewController(map: map)
        
        // Assign the delegate
        templatePicker.delegate = self
        
        // Present the template picker
        self.navigationController?.pushViewController(templatePicker, animated: true)
    }
}

extension TemplatePickerExample: TemplatePickerViewControllerDelegate {
    public func templatePickerViewControllerDidCancel(_ templatePickerViewController: TemplatePickerViewController) {
        // This is where you handle the user canceling the template picker
        
        // dismiss the template picker
        navigationController?.popToViewController(self, animated: true)
        
        let alert = UIAlertController(title: "TemplatePickerExample", message: "User cancelled", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        alert.preferredAction = action
        present(alert, animated: true)
    }
    
    public func templatePickerViewController(_ templatePickerViewController: TemplatePickerViewController, didSelect featureTemplateInfo: FeatureTemplateInfo) {
        // This is where you handle the user making a selection with the template picker
        
        // dismiss the template picker
        navigationController?.popToViewController(self, animated: true)
        
        let alert = UIAlertController(title: "TemplatePickerExample", message: "User selected \(featureTemplateInfo.featureTemplate.name)", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        alert.preferredAction = action
        present(alert, animated: true)
    }
}

//
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

class LayerContentsExample: MapViewController {
    var layerContentsVC: LayerContentsViewController?
    var layerContentsButton = UIBarButtonItem()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Bookmark button that will display the LayerContentsViewController.
        layerContentsButton = UIBarButtonItem(title: "Legend", style: .plain, target: self, action: #selector(showLayerContents))
        navigationItem.rightBarButtonItem = layerContentsButton

        // Create the map from a portal item and assign to the mapView.
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "16f1b8ba37b44dc3884afc8d5f454dd2")
        mapView.map = AGSMap(item: portalItem)
        
        // Create the LayerContentsViewController.
        layerContentsVC = LayerContentsViewController()
        layerContentsVC?.dataSource = DataSource(geoView: mapView)
        
        // Add a cancel button.
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        layerContentsVC?.navigationItem.leftBarButtonItem = cancelButton
    }
    
    @objc
    func showLayerContents() {
        if let layerContentsVC = layerContentsVC {
            // Display the layerContentsVC as a popover controller.
            layerContentsVC.modalPresentationStyle = .popover
            if let popoverPresentationController = layerContentsVC.popoverPresentationController {
                popoverPresentationController.delegate = self
                popoverPresentationController.barButtonItem = layerContentsButton
            }
            present(layerContentsVC, animated: true)
        }
    }
    
    @objc
    func cancel() {
        dismiss(animated: true)
    }
}

extension LayerContentsExample: UIPopoverPresentationControllerDelegate {
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

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
import ArcGIS

/// The `PopupController` does the work of wiring up an `AGSPopupsViewController` for you.
/// Through its use of the `AGSPopupsViewController`, it provides a complete
/// feature editing and collecting experience.
public class PopupController: NSObject, AGSPopupsViewControllerDelegate, AGSGeoViewTouchDelegate {
    private var lastPopupQueries = [AGSCancelable]()
    private var popupsViewController: AGSPopupsViewController?
    private let sketchEditor = AGSSketchEditor()
    private var lastSelectedFeature: AGSFeature?
    private var lastSelectedFeatureLayer: AGSFeatureLayer?
    private let addNewFeatureButtonItem: UIBarButtonItem
    
    /// The `UIViewController` that contains the `AGSGeoView`.
    public private(set) weak var geoViewController: UIViewController?
    
    /// The `AGSGeoView` that the `PopupController` is interacting with.
    public let geoView: AGSGeoView
    
    /// Indicates whether or not to push the `AGSPopupsViewController` onto the `UINavigationController`. The default is `true`.
    public var useNavigationControllerIfAvailable: Bool = true
    
    /// Instantiates a `PopupController`
    /// - Parameters:
    ///   - geoViewController: The `UIViewController` that contains the `AGSGeoView` that the `PopupController` will interact with
    ///   - geoView: The `AGSGeoView` that the `PopupController` will interact with
    ///   - takeOverTouchDelegate: Whether or not the `PopupController` will take over the `AGSGeoView's` `touchDelegate`.
    ///     If `false` then you must forward calls from the `AGSGeoViewTouchDelegate` to the `PopupController`. Defaults to `true`.
    ///   - showAddFeatureButton: If `true` then a `UIBarButtonItem` will be added to the `navigationItem` as a right-hand button.
    public init(geoViewController: UIViewController, geoView: AGSGeoView, takeOverTouchDelegate: Bool = true, showAddFeatureButton: Bool = true) {
        self.geoViewController = geoViewController
        self.geoView = geoView
        self.addNewFeatureButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        
        super.init()
        
        self.addNewFeatureButtonItem.target = self
        self.addNewFeatureButtonItem.action = #selector(addNewFeatureTap)
        
        if showAddFeatureButton {
            if let items = geoViewController.navigationItem.rightBarButtonItems {
                geoViewController.navigationItem.rightBarButtonItems = [self.addNewFeatureButtonItem] + items
            } else {
                geoViewController.navigationItem.rightBarButtonItem = self.addNewFeatureButtonItem
            }
        }
        
        if takeOverTouchDelegate {
            self.geoView.touchDelegate = self
        }
        
        sketchEditor.isVisible = true
        if let mapView = geoView as? AGSMapView {
            mapView.sketchEditor = sketchEditor
        }
    }
    
    private var addingNewFeature: Bool = false
    
    @objc
    private func addNewFeatureTap() {
        // if old pvc is being shown still for some reason, dismiss it
        self.cleanupLastPopupsViewController()
        
        guard let map = (geoView as? AGSMapView)?.map else {
            return
        }
        
        let templatePicker = TemplatePickerViewController(map: map)
        templatePicker.delegate = self
        
        let navigationController = UINavigationController(rootViewController: templatePicker)
        navigationController.modalPresentationStyle = .formSheet
        geoViewController?.present(navigationController, animated: true)
    }
    
    private func cleanupLastPopupsViewController() {
        unselectLastSelectedFeature()
        
        // if old pvc is being shown still for some reason, dismiss it
        if popupsViewController?.view?.window != nil {
            if popupsViewController == geoViewController?.navigationController?.topViewController {
                geoViewController?.navigationController?.popToViewController(geoViewController!, animated: true)
            } else if popupsViewController == geoViewController?.presentedViewController {
                popupsViewController?.dismiss(animated: true)
            }
        }
        
        // cleanup last time
        lastPopupQueries.forEach { $0.cancel() }
        popupsViewController = nil
        lastPopupQueries.removeAll()
    }
    
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        self.cleanupLastPopupsViewController()
        
        guard let mapView = geoView as? AGSMapView, mapView.map != nil else {
            return
        }
        
        let c = mapView.identifyLayers(atScreenPoint: screenPoint, tolerance: 10, returnPopupsOnly: true, maximumResultsPerLayer: 12) { [weak self] (identifyResults, error) -> Void in
            if let identifyResults = identifyResults {
                let popups = identifyResults.flatMap { $0.allPopups }
                self?.showPopups(popups)
            } else if let error = error {
                print("error identifying popups \(error)")
            }
        }
        lastPopupQueries.append(c)
    }
    
    private func showPopups(_ popups: [AGSPopup]) {
        guard !popups.isEmpty else {
            return
        }
        
        if let popupsViewController = self.popupsViewController {
            // If we already have a popupsViewController, then show additional
            popupsViewController.showAdditionalPopups(popups)
            return
        }
        
        // Otherwise we need to create the popupsViewController
        
        let containerStyle: AGSPopupsViewControllerContainerStyle = useNavigationControllerIfAvailable && geoViewController?.navigationController != nil ? .navigationController : .navigationBar
        
        let popupsViewController = AGSPopupsViewController(popups: popups, containerStyle: containerStyle)
        self.popupsViewController = popupsViewController
        popupsViewController.geometryEditingStyle = .toolbar
        popupsViewController.customDoneButton = nil
        popupsViewController.delegate = self
        
        if containerStyle == .navigationController {
            // set a back button for the pvc in the nav controller, showing modally, this is handled for us
            // need to do this so we can clean up (unselect feature, etc) when `back` is tapped
            let doneViewingBbi = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(doneViewingInNavController))
            popupsViewController.customDoneButton = doneViewingBbi
            popupsViewController.navigationItem.leftBarButtonItem = doneViewingBbi
            
            geoViewController?.navigationController?.pushViewController(popupsViewController, animated: true)
        } else {
            geoViewController?.present(popupsViewController, animated: true)
        }
    }
    
    @objc
    private func doneViewingInNavController() {
        guard let popupsViewController = popupsViewController else {
            return
        }
        popupsViewControllerDidFinishViewingPopups(popupsViewController)
    }
    
    private func unselectLastSelectedFeature() {
        guard let feature = lastSelectedFeature,
            let layer = lastSelectedFeatureLayer else {
                return
        }
        
        layer.unselectFeature(feature)
        lastSelectedFeature = nil
        lastSelectedFeatureLayer = nil
    }
    
    private var geoViewControllerOriginalRightBarButtonItems: [UIBarButtonItem]?
    private var editingGeometry: Bool = false
    
    private func navigateToMapActionForGeometryEditing() {
        editingGeometry = true
        
        if let geoViewController = geoViewController, let nc = geoViewController.navigationController {
            // if there is a navigationController available add button to go back to popups when done editing geometry
            geoViewControllerOriginalRightBarButtonItems = geoViewController.navigationItem.rightBarButtonItems
            let backToPvcButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(navigateBackToPopupsFromGeometryEditing))
            geoViewController.navigationItem.rightBarButtonItem = backToPvcButton
            
            if useNavigationControllerIfAvailable {
                nc.popToViewController(geoViewController, animated: true)
            } else {
                popupsViewController?.dismiss(animated: true)
            }
        } else {
            // in this case developer needs to have a button that calls `navigateBackToPopupsFromGeometryEditing`
            popupsViewController?.dismiss(animated: true)
        }
    }
    
    @objc
    private func navigateBackToPopupsFromGeometryEditing() {
        guard let popupsViewController = popupsViewController else {
            return
        }
        
        editingGeometry = false
        
        if let geoViewController = geoViewController, let nc = geoViewController.navigationController {
            // if there is a navigationController available reset to original buttons
            geoViewController.navigationItem.rightBarButtonItems = geoViewControllerOriginalRightBarButtonItems
            geoViewControllerOriginalRightBarButtonItems = nil
            
            if useNavigationControllerIfAvailable {
                nc.pushViewController(popupsViewController, animated: true)
            } else {
                geoViewController.present(popupsViewController, animated: true)
            }
        } else {
            geoViewController?.present(popupsViewController, animated: true)
        }
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, sketchEditorFor popup: AGSPopup) -> AGSSketchEditor? {
        // give the popupsViewController the sketchEditor
        
        if let g = popup.geoElement.geometry {
            self.sketchEditor.start(with: g)
        } else if let f = popup.geoElement as? AGSFeature, let ft = f.featureTable as? AGSArcGISFeatureTable {
            self.sketchEditor.start(with: ft.geometryType)
        } else {
            self.sketchEditor.start(with: AGSSketchCreationMode.polygon)
        }
        
        return self.sketchEditor
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, readyToEditGeometryWith sketchEditor: AGSSketchEditor?, for popup: AGSPopup) {
        // geometry editing has started - show map
        self.navigateToMapActionForGeometryEditing()
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didChangeToCurrentPopup popup: AGSPopup) {
        guard let f = popup.geoElement as? AGSArcGISFeature,
            let ft = f.featureTable as? AGSServiceFeatureTable,
            let fl = ft.layer as? AGSFeatureLayer else {
                return
        }
        
        unselectLastSelectedFeature()
        
        fl.select(f)
        lastSelectedFeature = f
        lastSelectedFeatureLayer = fl
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didFinishEditingFor popup: AGSPopup) {
        // geometry editing has ended
        self.sketchEditor.stop()
        
        // apply edits for service feature table
        if let f = popup.geoElement as? AGSArcGISFeature, let ft = f.featureTable as? AGSServiceFeatureTable {
            ft.applyEdits { (results, error) in
                if let error = error {
                    // In this case it is a service level error
                    print("error applying edits: \(error)")
                }
                
                if let results = results {
                    let editErrors = results.flatMap { self.checkFeatureEditResult($0) }
                    if editErrors.isEmpty {
                        print("applied all edits successfully")
                    } else {
                        // These would be feature level edit errors
                        print("apply edits failed: \(editErrors)")
                    }
                }
            }
        }
        
        // reset flag
        addingNewFeature = false
    }
    
    /// This pulls out any nested errors from a feature edit result
    private func checkFeatureEditResult(_ featureEditResult: AGSFeatureEditResult) -> [Error] {
        var errors = [Error]()
        if let error = featureEditResult.error {
            errors.append(error)
        }
        errors.append(contentsOf: featureEditResult.attachmentResults.compactMap { $0.error })
        return errors
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didCancelEditingFor popup: AGSPopup) {
        // geometry editing has ended
        self.sketchEditor.stop()
        
        if addingNewFeature {
            // if was adding new feature, then hide the popup, don't show viewing mode
            self.cleanupLastPopupsViewController()
        }
        
        // reset flag
        addingNewFeature = false
    }
    
    public func popupsViewControllerDidFinishViewingPopups(_ popupsViewController: AGSPopupsViewController) {
        self.cleanupLastPopupsViewController()
    }
}

extension PopupController: TemplatePickerViewControllerDelegate {
    public func templatePickerViewControllerDidCancel(_ templatePickerViewController: TemplatePickerViewController) {
        templatePickerViewController.dismiss(animated: true)
    }
    
    public func templatePickerViewController(_ templatePickerViewController: TemplatePickerViewController, didSelect featureTemplateInfo: FeatureTemplateInfo) {
        templatePickerViewController.dismiss(animated: true) {
            guard let feature = featureTemplateInfo.featureTable.createFeature(with: featureTemplateInfo.featureTemplate) else {
                return
            }
            
            self.addingNewFeature = true
            let popup = AGSPopup(geoElement: feature, popupDefinition: featureTemplateInfo.featureLayer.popupDefinition)
            self.showPopups([popup])
            self.popupsViewController?.startEditingCurrentPopup()
        }
    }
}

fileprivate extension AGSIdentifyLayerResult {
    var allPopups: [AGSPopup] {
        return popups + sublayerResults.flatMap { $0.allPopups }
    }
}

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

public class PopupController: NSObject, AGSPopupsViewControllerDelegate, AGSGeoViewTouchDelegate {
    
    var lastPopupQueries : [AGSCancelable]?
    var pvc : AGSPopupsViewController?
    var sketchEditor = AGSSketchEditor()
    var lastSelectedFeature : AGSFeature?
    var lastSelectedFeatureLayer : AGSFeatureLayer?
    var addNewFeatureButton : UIBarButtonItem
    
    weak var geoViewController: UIViewController?
    var geoView: AGSGeoView
    public var useNavigationControllerIfAvailable : Bool = true
    
    public init(geoViewController: UIViewController, geoView: AGSGeoView, takeOverGeoViewDelegate: Bool = true, showAddFeatureButton: Bool = true){
        
        self.geoViewController = geoViewController
        self.geoView = geoView
        //self.addNewFeatureButton = UIBarButtonItem(title: "Add Feature", style: .plain, target: nil, action: nil)
        self.addNewFeatureButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        
        super.init()
        
        self.addNewFeatureButton.target = self
        self.addNewFeatureButton.action = #selector(addNewFeatureTap)
        
        if showAddFeatureButton{
            if let items = geoViewController.navigationItem.rightBarButtonItems{
                geoViewController.navigationItem.rightBarButtonItems = [self.addNewFeatureButton] + items
            }
            else{
                geoViewController.navigationItem.rightBarButtonItem = self.addNewFeatureButton
            }
        }
        
        if takeOverGeoViewDelegate{
            self.geoView.touchDelegate = self
        }
        
        sketchEditor.isVisible = true
        if let mapView = geoView as? AGSMapView{
            mapView.sketchEditor = sketchEditor
        }
    }
    
    var addingNewFeature : Bool = false
    
    @objc func addNewFeatureTap(){
        
        // if old pvc is being shown still for some reason, dismiss it
        self.cleanupLastPopupsViewController()
        
        guard let map = (geoView as? AGSMapView)?.map else{
            return
        }
        
        let fvc = FeatureTypesViewController(map: map)
        fvc.delegate = self
        
        let navigationController = UINavigationController(rootViewController: fvc)
        navigationController.modalPresentationStyle = .formSheet
        UIApplication.shared.topViewController()?.present(navigationController, animated: true)
    }
    
    
    func cleanupLastPopupsViewController(){
        unselectLastSelectedFeature()
        
        // if old pvc is being shown still for some reason, dismiss it
        if pvc?.view?.window != nil {
            if pvc == geoViewController?.navigationController?.topViewController{
                _ = geoViewController?.navigationController?.popViewController(animated: true)
            }
            else if pvc == geoViewController?.presentedViewController{
                pvc?.dismiss(animated: true, completion: nil)
            }
        }
        
        // cleanup last time
        lastPopupQueries?.forEach{ $0.cancel() }
        pvc = nil;
        lastPopupQueries = [AGSCancelable]()
    }
    
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        
        self.cleanupLastPopupsViewController()
        
        guard let mapView = geoView as? AGSMapView , mapView.map != nil else{
            return
        }
        
        let c = mapView.identifyLayers(atScreenPoint: screenPoint, tolerance: 10, returnPopupsOnly: true, maximumResultsPerLayer: 12) { [weak self] (identifyResults, error) -> Void in
            
            if let identifyResults = identifyResults {
                var popups = [AGSPopup]()
                
                func processIdentifyResults(identifyResults: [AGSIdentifyLayerResult]){
                    for identifyResult in identifyResults {
                        popups.append(contentsOf: identifyResult.popups)
                        processIdentifyResults(identifyResults: identifyResult.sublayerResults)
                    }
                }
                processIdentifyResults(identifyResults: identifyResults)
                
                self?.showPopups(popups)
            }
            else if let error = error {
                print("error identifying popups \(error)")
            }
        }
        lastPopupQueries?.append(c)
    }
    
    func showPopups(_ popups: [AGSPopup]?){
        
        guard let popups = popups else{
            return
        }
        
        if popups.count > 0{
            if self.pvc == nil{
                
                let containerStyle : AGSPopupsViewControllerContainerStyle = useNavigationControllerIfAvailable && geoViewController?.navigationController != nil ? .navigationController : .navigationBar
                
                self.pvc = AGSPopupsViewController(popups: popups, containerStyle: containerStyle)
                self.pvc?.geometryEditingStyle = .toolbar
                self.pvc?.customDoneButton = nil
                self.pvc?.delegate = self
                
                if useNavigationControllerIfAvailable, let nc = geoViewController?.navigationController{
                    // set a back button for the pvc in the nav controller, showing modally, this is handled for us
                    // need to do this so we can clean up (unselect feature, etc) when `back` is tapped
                    let doneViewingBbi = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(doneViewingInNavController))
                    pvc?.customDoneButton = doneViewingBbi
                    pvc?.navigationItem.leftBarButtonItem = doneViewingBbi
                    
                    nc.pushViewController(self.pvc!, animated: true)
                }
                else{
                    geoViewController?.present(self.pvc!, animated: true, completion: nil)
                }
                
            }
            else{
                self.pvc?.showAdditionalPopups(popups)
            }
        }
    }
    
    @objc func doneViewingInNavController(){
        guard let pvc = self.pvc else {
            return
        }
        popupsViewControllerDidFinishViewingPopups(pvc)
    }
    
    func unselectLastSelectedFeature(){
        if let lastSelectedFeature = self.lastSelectedFeature,
            let lastSelectedFeatureLayer = self.lastSelectedFeatureLayer{
            lastSelectedFeatureLayer.unselectFeature(lastSelectedFeature)
            self.lastSelectedFeature = nil
            self.lastSelectedFeatureLayer = nil
        }
    }
    
    var geoViewControllerOriginalRightBarButtonItems : [UIBarButtonItem]?
    var editingGeometry : Bool = false
    
    func navigateToMapActionForGeometryEditing() {
        
        editingGeometry = true
        
        if let geoViewController = geoViewController, let nc = geoViewController.navigationController{
            // if there is a navigationController available add button to go back to popups when done editing geometry
            geoViewControllerOriginalRightBarButtonItems = geoViewController.navigationItem.rightBarButtonItems
            let backToPvcButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(navigateBackToPopupsFromGeometryEditing))
            geoViewController.navigationItem.rightBarButtonItem = backToPvcButton
            
            if useNavigationControllerIfAvailable{
                nc.popToViewController(geoViewController, animated: true)
            }
            else{
                pvc?.dismiss(animated: true, completion: nil)
            }
        }
        else{
            // in this case developer needs to have a button that calls `navigateBackToPopupsFromGeometryEditing`
            pvc?.dismiss(animated: true, completion: nil)
        }
        
    }
    
    @objc func navigateBackToPopupsFromGeometryEditing(){
        
        guard let pvc = self.pvc else{
            return
        }
        
        editingGeometry = false
        
        if let geoViewController = geoViewController, let nc = geoViewController.navigationController{
            // if there is a navigationController available reset to original buttons
            geoViewController.navigationItem.rightBarButtonItems = geoViewControllerOriginalRightBarButtonItems
            geoViewControllerOriginalRightBarButtonItems = nil
            
            if useNavigationControllerIfAvailable{
                nc.pushViewController(pvc, animated: true)
            }
            else{
                geoViewController.present(pvc, animated: true, completion: nil)
            }
        }
        else{
            geoViewController?.present(pvc, animated: true, completion: nil)
        }
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, sketchEditorFor popup: AGSPopup) -> AGSSketchEditor? {
        
        // give the popupsViewController the sketchEditor
        
        if let g = popup.geoElement.geometry{
            self.sketchEditor.start(with: g)
        }
        else if let f = popup.geoElement as? AGSFeature, let ft = f.featureTable as? AGSArcGISFeatureTable{
            self.sketchEditor.start(with: ft.geometryType)
        }
        else{
            self.sketchEditor.start(with: AGSSketchCreationMode.polygon)
        }
        
        return self.sketchEditor
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, readyToEditGeometryWith sketchEditor: AGSSketchEditor?, for popup: AGSPopup) {
        // geometry editing has started - show map
        self.navigateToMapActionForGeometryEditing()
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didChangeToCurrentPopup popup: AGSPopup) {
        if let f = popup.geoElement as? AGSArcGISFeature,
            let ft = f.featureTable as? AGSServiceFeatureTable,
            let fl = ft.featureLayer{
            
            unselectLastSelectedFeature()
            
            fl.select(f)
            self.lastSelectedFeature = f
            self.lastSelectedFeatureLayer = fl
        }
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didDeleteFor popup: AGSPopup) {
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didFinishEditingFor popup: AGSPopup) {
        
        // geometry editing has ended
        self.sketchEditor.stop()
        
        // apply edits for service feature table
        if let f = popup.geoElement as? AGSArcGISFeature, let ft = f.featureTable as? AGSServiceFeatureTable{
            ft.applyEdits { (results, error) in
                //if let error = error{
                    //print("error applying edits: \(error)")
                //}
                //else{
                    //print("possible success applying edits...");
                //}
            }
        }
        
        // reset flag
        addingNewFeature = false
    }
    
    public func popupsViewController(_ popupsViewController: AGSPopupsViewController, didCancelEditingFor popup: AGSPopup) {
        // geometry editing has ended
        self.sketchEditor.stop()
        
        if addingNewFeature{
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

extension PopupController: FeatureTypesViewControllerDelegate {
    
    public func featureTypesViewControllerDidCancel(_ featureTypesViewController: FeatureTypesViewController) {
        featureTypesViewController.dismiss(animated: true)
    }
    
    public func featureTypesViewControllerDidSelectFeatureType(_ featureTypesViewController: FeatureTypesViewController, featureTypeInfo: FeatureTypeInfo) {
        featureTypesViewController.dismiss(animated: true){
            if let feature = featureTypeInfo.featureTable.createFeature(with: featureTypeInfo.featureType){
                self.addingNewFeature = true
                let popup = AGSPopup(geoElement: feature, popupDefinition: featureTypeInfo.featureLayer.popupDefinition)
                self.showPopups([popup])
                // NOTE: This works around a bug where editing doesn't start until the view is loaded
                _ = self.pvc?.view
                self.pvc?.startEditingCurrentPopup()
            }
        }
    }
}










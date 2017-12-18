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

public class SketchToolbar: UIView {
    
    open var sketchEditorGeometryChangedHandler: (() -> Swift.Void)?
    let sketchEditor = AGSSketchEditor()
    
    let toolbar : UIToolbar
    let undoButton : UIBarButtonItem
    let redoButton : UIBarButtonItem
    let addPartButton : UIBarButtonItem
    let clearButton : UIBarButtonItem
    var segControl : UISegmentedControl
    var segControlItem : UIBarButtonItem
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required public init(mapView: AGSMapView){
        
        mapView.sketchEditor = sketchEditor
        
        toolbar = UIToolbar()
        
        let bundle = Bundle(for: type(of: self))
        let pointImage = UIImage(named: "SketchPoint", in: bundle, compatibleWith: nil)
        let multipointImage = UIImage(named: "SketchMultipoint", in: bundle, compatibleWith: nil)
        let polylineImage = UIImage(named: "SketchPolyline", in: bundle, compatibleWith: nil)
        let polygonImage = UIImage(named: "SketchPolygon", in: bundle, compatibleWith: nil)
        let freehandPolylineImage = UIImage(named: "SketchFreehandPolyline", in: bundle, compatibleWith: nil)
        let freehandPolygonImage = UIImage(named: "SketchFreehandPolygon", in: bundle, compatibleWith: nil)
        let undoImage = UIImage(named: "Undo", in: bundle, compatibleWith: nil)
        let redoImage = UIImage(named: "Redo", in: bundle, compatibleWith: nil)
        
        undoButton = UIBarButtonItem(image: undoImage, style: .plain, target: nil, action: nil)
        redoButton = UIBarButtonItem(image: redoImage, style: .plain, target: nil, action: nil)
        clearButton = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action:nil)
        addPartButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        addPartButton.isEnabled = false

        segControl = UISegmentedControl(items: ["Point", "Multipoint", "Polyline", "Polygon", "Freehand Polyline", "Freehand Polygon"])
        segControl.setImage(pointImage, forSegmentAt: 0)
        segControl.setImage(multipointImage, forSegmentAt: 1)
        segControl.setImage(polylineImage, forSegmentAt: 2)
        segControl.setImage(polygonImage, forSegmentAt: 3)
        segControl.setImage(freehandPolylineImage, forSegmentAt: 4)
        segControl.setImage(freehandPolygonImage, forSegmentAt: 5)
        segControlItem = UIBarButtonItem(customView: segControl)
        
        super.init(frame:CGRect.zero)
        
        undoButton.target = self
        undoButton.action = #selector(undoButtonTap)
        redoButton.target = self
        redoButton.action = #selector(redoButtonTap)
        clearButton.target = self
        clearButton.action = #selector(clearButtonTap)
        addPartButton.target = self
        addPartButton.action = #selector(addPartButtonTap)
        
        segControl.addTarget(self, action: #selector(segmentControlValueChanged), for: .valueChanged)
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [segControlItem, addPartButton, flex, undoButton, redoButton, clearButton]
        
        // auto layout
        addSubview(toolbar)
        
        segControl.selectedSegmentIndex = 0
        segmentControlValueChanged()
        
        // notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AGSSketchEditorGeometryDidChange, object: sketchEditor, queue: nil, using: sketchDidChange)
        sketchDidChange(notification: nil)
    }
    
    var didSetConstraints : Bool = false
    
    public override func updateConstraints() {
        
        super.updateConstraints()
        
        guard !didSetConstraints else{
            return
        }
        
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["view":self, "toolbar":toolbar] as [String: UIView]
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[toolbar]-0-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[toolbar(44)]-0-|", options: [], metrics: nil, views: views))
        
        didSetConstraints = true
    }
    
    override public class var requiresConstraintBasedLayout : Bool {
        return true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func segmentControlValueChanged(){
        //
        // keep add part button disabled
        addPartButton.isEnabled = false
        
        if segControl.selectedSegmentIndex == 0{
            startPointMode()
        }
        else if segControl.selectedSegmentIndex == 1{
            startMultipointMode()
        }
        else if segControl.selectedSegmentIndex == 2{
            addPartButton.isEnabled = true
            startLineMode()
        }
        else if segControl.selectedSegmentIndex == 3{
            addPartButton.isEnabled = true
            startPolygonMode()
        }
        else if segControl.selectedSegmentIndex == 4{
            startFreehandPolylineMode()
        }
        else if segControl.selectedSegmentIndex == 5{
            startFreehandPolylgonMode()
        }
    }
    
    func startPointMode(){
        
        guard sketchEditor.creationMode != .point else{
            return
        }
        
        sketchEditor.start(with: AGSSketchCreationMode.point)
    }
    
    func startMultipointMode(){
        
        guard sketchEditor.creationMode != .multipoint else{
            return
        }
        
        sketchEditor.start(with: AGSSketchCreationMode.multipoint)
    }
 
    func startLineMode(){
        
        guard sketchEditor.creationMode != .polyline else{
            return
        }
        
        sketchEditor.start(with: AGSSketchCreationMode.polyline)
    }
    
    func startPolygonMode(){
        
        guard sketchEditor.creationMode != .polygon else{
            return
        }
        
        sketchEditor.start(with: AGSSketchCreationMode.polygon)
    }
    
    func startFreehandPolylineMode(){
        
        guard sketchEditor.creationMode != .freehandPolyline else{
            return
        }
        
        sketchEditor.start(with: AGSSketchCreationMode.freehandPolyline)
    }
    
    func startFreehandPolylgonMode(){
        
        guard sketchEditor.creationMode != .freehandPolygon else{
            return
        }
        
        sketchEditor.start(with: AGSSketchCreationMode.freehandPolygon)
    }
    
    func undoButtonTap(){
        sketchEditor.undoManager.undo()
    }
    
    func redoButtonTap(){
        sketchEditor.undoManager.redo()
    }
    
    func clearButtonTap(){
        sketchEditor.clearGeometry()
    }
    
    func addPartButtonTap(){
        let geometry = sketchEditor.geometry
        if geometry?.geometryType == .polyline || geometry?.geometryType == .polygon {
            let multipartBuilder = sketchEditor.geometry?.toBuilder() as! AGSMultipartBuilder
            multipartBuilder.parts.add(AGSMutablePart(spatialReference: geometry?.spatialReference))
            sketchEditor.replaceGeometry(multipartBuilder.toGeometry())
        }
    }
    
    func sketchDidChange(notification: Notification?){
        self.sketchEditorGeometryChangedHandler?()
    }
    
}










// Copyright 2017 Esri.

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

struct Measurement {
    let value: Double
    let unit: AGSUnit
}

class MeasureResultView: UIView{
    
    var measurement: Measurement? {
        didSet{
            if let measurement = measurement{
                valueLabel.text = valueString()
                unitButton.setTitle(stringForUnit(measurement.unit), for: .normal)
                unitButton.isHidden = false
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    var helpText: String?{
        didSet{
            if let helpText = helpText{
                valueLabel.text = helpText
                unitButton.isHidden = true
                unitButton.setTitle(nil, for: .normal)
            }
        }
    }
    
    var valueLabel: UILabel
    var unitButton: UIButton
    var stackView: UIStackView
    
    let numberFormatter = NumberFormatter()
    var buttonTapHandler: (()->(Void))?
    
    override var intrinsicContentSize: CGSize{
        return stackView.systemLayoutSizeFitting(CGSize(width: 0, height: 0), withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel)
    }
    
    override init(frame: CGRect) {
        
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.roundingMode = .halfUp
        
        valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.textAlignment = .right
        valueLabel.textColor = UIColor.darkGray
        valueLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        
        unitButton = UIButton(type: .system)
        unitButton.translatesAutoresizingMaskIntoConstraints = false
        unitButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
        unitButton.titleLabel?.textAlignment = .left
        
        stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4.0
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        stackView.isLayoutMarginsRelativeArrangement = true
        
        super.init(frame: frame)
        
        unitButton.addTarget(self, action: #selector(buttonTap), for: .touchUpInside)
        
        layer.cornerRadius = 4
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 1
        clipsToBounds = true
        
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(unitButton)
        
        addSubview(stackView)
        
        stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        stackView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        valueLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 500), for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        unitButton.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 499), for: .horizontal)
        unitButton.setContentHuggingPriority(.required, for: .horizontal)
        
        let tgr = UITapGestureRecognizer(target: self, action: #selector(buttonTap))
        addGestureRecognizer(tgr)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    @objc func buttonTap(){
        guard unitButton.isHidden == false else{
            return
        }
        buttonTapHandler?()
    }
    
    func valueString() -> String?{
        
        guard let measurement = measurement else{
            return ""
        }
        
        // if number greater than some value then don't show fraction
        
        if measurement.value > 1_000{
            numberFormatter.maximumFractionDigits = 0
        }
        else{
            numberFormatter.maximumFractionDigits = 2
        }
        
        guard let measurementValueString = numberFormatter.string(for: measurement.value) else {
            return ""
        }
        
        return measurementValueString
    }
    
    func stringForUnit(_ unit: AGSUnit?) -> String?{
        guard let unit = unit else {
            return ""
        }
        return unit.pluralDisplayName
    }
    
}

private enum MeasureToolbarMode{
    case length
    case area
    case feature
}

public class MeasureToolbar: UIToolbar, AGSGeoViewTouchDelegate {
    
    
    // Exposed so that the user can customize the sketch editor styles.
    // Consumers of the MeasureToolbar should not mutate the sketch editor state
    // other than it's style.
    public let lineSketchEditor = AGSSketchEditor()
    public let areaSketchEditor = AGSSketchEditor()
    
    // Exposed so that the symbology and selection colors can be customized.
    public private(set) var selectionLineSymbol: AGSSymbol?
    public private(set)var selectionFillSymbol: AGSSymbol?
    @available(iOS, deprecated, message: "Use `color` property exposed through `AGSGeoView.selectionProperties`")
    public var selectionColor: UIColor? {
        return mapView?.selectionProperties.color
    }

    public var mapView: AGSMapView? {
        didSet{
            guard mapView != oldValue else { return }
            unbindFromMapView(mapView: oldValue)
            bindToMapView(mapView: mapView)
            updateMeasurement()
        }
    }
    
    public var selectedLinearUnit: AGSLinearUnit = {
        if NSLocale.current.usesMetricSystem {
            return AGSLinearUnit.kilometers()
        } else {
            return AGSLinearUnit.miles()
        }
        }() {
        didSet {
            updateMeasurement()
        }
    }
    public var selectedAreaUnit: AGSAreaUnit = {
        if NSLocale.current.usesMetricSystem {
            return AGSAreaUnit(unitID: AGSAreaUnitID.hectares) ?? AGSAreaUnit.squareKilometers()
        } else {
            return AGSAreaUnit(unitID: AGSAreaUnitID.acres) ?? AGSAreaUnit.squareMiles()
        }
        }() {
        didSet {
            updateMeasurement()
        }
    }
    
    private static let identifyTolerance = 16.0
    
    private var selectionOverlay: AGSGraphicsOverlay?
    private var selectedGeometry: AGSGeometry? {
        didSet {
            guard selectedGeometry != oldValue else { return }
            updateMeasurement()
        }
    }
    
    private let resultView: MeasureResultView = MeasureResultView()
    
    private var undoButton: UIBarButtonItem!
    private var redoButton: UIBarButtonItem!
    private var clearButton: UIBarButtonItem!
    private var rightHiddenPlaceholderView: UIView!
    private var leftHiddenPlaceholderView: UIView!
    private var segControl: UISegmentedControl!
    private var segControlItem: UIBarButtonItem!
    private var mode: MeasureToolbarMode? = nil {
        didSet {
            guard mode != oldValue else { return }
            updateMeasurement()
        }
    }
    
    private let geodeticCurveType: AGSGeodeticCurveType = .geodesic
    // This is the threshold for which when the planar measurements are above,
    // it will switch to geodetic calculations. Set it to Double.infinity for
    // always doing geodetic calculations (but be careful, they can get slow when they have to measure
    // too much length/area).
    // Set it to 0 to never do geodetic calculations (less accurate).
    private let planarLengthMetersThreshold: Double = 10_000_000
    private let planarAreaSquareMilesThreshold: Double = 1_000_000
    
    deinit {
        unbindFromMapView(mapView: mapView)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInitialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    convenience public init(mapView: AGSMapView){
        self.init(frame: .zero)
        self.mapView = mapView
        // because didSet doesn't happen in constructors
        bindToMapView(mapView: mapView)
    }
    
    private var sketchModeButtons: [UIBarButtonItem] = []
    private var selectModeButtons: [UIBarButtonItem] = []
    
    private func sharedInitialization(){
        
        let bundle = Bundle(for: type(of: self))
        let measureLengthImage = UIImage(named: "MeasureLength", in: bundle, compatibleWith: nil)
        let measureAreaImage = UIImage(named: "MeasureArea", in: bundle, compatibleWith: nil)
        let measureFeatureImage = UIImage(named: "MeasureFeature", in: bundle, compatibleWith: nil)
        let undoImage = UIImage(named: "Undo", in: bundle, compatibleWith: nil)
        let redoImage = UIImage(named: "Redo", in: bundle, compatibleWith: nil)
        
        undoButton = UIBarButtonItem(image: undoImage, style: .plain, target: nil, action: nil)
        redoButton = UIBarButtonItem(image: redoImage, style: .plain, target: nil, action: nil)
        clearButton = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action:nil)
        
        segControl = UISegmentedControl(items: ["Length", "Area", "Select"])
        segControl.setImage(measureLengthImage, forSegmentAt: 0)
        segControl.setImage(measureAreaImage, forSegmentAt: 1)
        segControl.setImage(measureFeatureImage, forSegmentAt: 2)
        segControlItem = UIBarButtonItem(customView: segControl)
        
        resultView.buttonTapHandler = { [weak self] in
            self?.unitsButtonTap()
        }
        
        undoButton.target = self
        undoButton.action = #selector(undoButtonTap)
        redoButton.target = self
        redoButton.action = #selector(redoButtonTap)
        clearButton.target = self
        clearButton.action = #selector(clearButtonTap)
        
        segControl.addTarget(self, action: #selector(segmentControlValueChanged), for: .valueChanged)
        
        let flexButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        rightHiddenPlaceholderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let rightHiddenPlaceholderButton = UIBarButtonItem(customView: rightHiddenPlaceholderView)
        rightHiddenPlaceholderButton.isEnabled = false
        
        leftHiddenPlaceholderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let leftHiddenPlaceholderButton = UIBarButtonItem(customView: leftHiddenPlaceholderView)
        leftHiddenPlaceholderButton.isEnabled = false
        
        sketchModeButtons = [segControlItem, leftHiddenPlaceholderButton, flexButton, rightHiddenPlaceholderButton, undoButton, redoButton, clearButton]
        selectModeButtons = [segControlItem, leftHiddenPlaceholderButton, flexButton, rightHiddenPlaceholderButton]
        
        // notification
        NotificationCenter.default.addObserver(self, selector: #selector(sketchEditorGeometryDidChange(_:)), name: .AGSSketchEditorGeometryDidChange, object: nil)
    }
    
    private func bindToMapView(mapView: AGSMapView?){
        mapView?.touchDelegate = self
        
        if let mapView = mapView{
            // defaults for symbology
            selectionLineSymbol = lineSketchEditor.style.lineSymbol
            let fillColor = mapView.selectionProperties.color.withAlphaComponent(0.25)
            let sfs = AGSSimpleFillSymbol(style: .solid, color: fillColor, outline: selectionLineSymbol as? AGSSimpleLineSymbol)
            selectionFillSymbol = sfs
            
            let selectionOverlay = AGSGraphicsOverlay()
            self.selectionOverlay = selectionOverlay
            mapView.graphicsOverlays.add(selectionOverlay)
            
            // set initial mode
            segControl.selectedSegmentIndex = 0
            segmentControlValueChanged()
        }
    }
    
    private func unbindFromMapView(mapView: AGSMapView?){
        mapView?.sketchEditor = nil
        mapView?.touchDelegate = nil
        
        if let mapView = mapView, let selectionOverlay = selectionOverlay{
            mapView.graphicsOverlays.remove(selectionOverlay)
        }
    }
    
    private var didSetConstraints: Bool = false
    
    public override func updateConstraints() {
        
        super.updateConstraints()
        
        guard !didSetConstraints else{
            return
        }
        
        // NOTE: Cannot add resultView as a subview until updateConstraints
        // or else the constraints wont be setup correctly.
        addSubview(resultView)
        
        resultView.translatesAutoresizingMaskIntoConstraints = false
        
        resultView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        // The following constraints cause the results view to be centered,
        // however if the content is too big it is allowed to grow to the right.
        // The two centerX constraints are arranged with specific priorities to cause this.
        
        let space: CGFloat = 2
        
        let c1 = resultView.leadingAnchor.constraint(greaterThanOrEqualTo: leftHiddenPlaceholderView.trailingAnchor, constant: space)
        c1.priority = .required
        
        // have to give this just below required, otherwise before the left and right views are setup in
        // their proper locations we can get constraint errors
        let c2 = resultView.trailingAnchor.constraint(lessThanOrEqualTo: rightHiddenPlaceholderView.leadingAnchor, constant: -space)
        c2.priority = UILayoutPriority(rawValue: 999)
        
        let c3 = NSLayoutConstraint(item: resultView, attribute: .centerX, relatedBy: .greaterThanOrEqual, toItem: self, attribute: .centerX, multiplier: 1, constant: 0)
        c3.priority = .required
        
        let c4 = NSLayoutConstraint(item: resultView, attribute: .centerX, relatedBy: .lessThanOrEqual, toItem: self, attribute: .centerX, multiplier: 1, constant: 0)
        c4.priority = .defaultLow
        
        NSLayoutConstraint.activate([c1, c2, c3, c4])
        
        didSetConstraints = true
    }
    
    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    @objc private func segmentControlValueChanged(){
        
        if segControl.selectedSegmentIndex == 0{
            startLineMode()
        }
        else if segControl.selectedSegmentIndex == 1{
            startAreaMode()
        }
        else if segControl.selectedSegmentIndex == 2{
            startFeatureMode()
        }
    }
    
    private func startLineMode(){
        
        guard mode != MeasureToolbarMode.length else{
            return
        }
        
        mode = .length
        selectionOverlay?.isVisible = false
        self.items = sketchModeButtons
        mapView?.sketchEditor = lineSketchEditor
        
        if !lineSketchEditor.isStarted{
            lineSketchEditor.start(with: AGSSketchCreationMode.polyline)
        }
    }
    
    private func startAreaMode(){
        
        guard mode != MeasureToolbarMode.area else{
            return
        }
        
        mode = .area
        selectionOverlay?.isVisible = false
        self.items = sketchModeButtons
        mapView?.sketchEditor = areaSketchEditor
        
        if !areaSketchEditor.isStarted{
            areaSketchEditor.start(with: AGSSketchCreationMode.polygon)
        }
    }
    
    private func startFeatureMode(){
        
        guard mode != MeasureToolbarMode.feature else{
            return
        }
        
        mode = .feature
        selectionOverlay?.isVisible = true
        self.items = selectModeButtons
        mapView?.sketchEditor = nil
    }
    
    @objc private func undoButtonTap(){
        mapView?.sketchEditor?.undoManager.undo()
    }
    
    @objc private func redoButtonTap(){
        mapView?.sketchEditor?.undoManager.redo()
    }
    
    @objc private func clearButtonTap(){
        mapView?.sketchEditor?.clearGeometry()
    }
    
    private func unitsButtonTap(){
        let units: [AGSUnit]
        let selectedUnit: AGSUnit
        if mapView?.sketchEditor == lineSketchEditor ||
            selectedGeometry?.geometryType == .polyline {
            
            let linearUnitIDs: [AGSLinearUnitID] = [.centimeters, .feet, .inches, .kilometers, .meters, .miles, .millimeters, .nauticalMiles, .yards]
            units = linearUnitIDs.compactMap { AGSLinearUnit(unitID: $0) }
            selectedUnit = selectedLinearUnit
        } else if mapView?.sketchEditor == areaSketchEditor ||
            selectedGeometry?.geometryType == .envelope ||
            selectedGeometry?.geometryType == .polygon {
            
            let areaUnitIDs: [AGSAreaUnitID] = [.acres, .hectares, .squareCentimeters, .squareDecimeters, .squareFeet, .squareKilometers, .squareMeters, .squareMillimeters, .squareMiles, .squareYards]
            units = areaUnitIDs.compactMap { AGSAreaUnit(unitID: $0) }
            selectedUnit = selectedAreaUnit
        } else {
            return
        }
        
        let unitsViewController = UnitsViewController()
        unitsViewController.delegate = self
        unitsViewController.units = units.sorted { $0.pluralDisplayName < $1.pluralDisplayName }
        unitsViewController.selectedUnit = selectedUnit
        
        let navigationController = UINavigationController(rootViewController: unitsViewController)
        navigationController.modalPresentationStyle = .formSheet
        
        UIApplication.shared.topViewController()?.present(navigationController, animated: true)
    }
    
    /// Called in response to
    /// `Notification.Name.AGSSketchEditorGeometryDidChange` being posted.
    ///
    /// - Parameter notification: The posted notification.
    @objc private func sketchEditorGeometryDidChange(_ notification: Notification) {
        guard let sketchEditor = notification.object as? AGSSketchEditor,
            sketchEditor == lineSketchEditor || sketchEditor == areaSketchEditor else {
                return
        }
        updateMeasurement()
    }
    
    /// Updates the measurement displayed to the user based on the current mode.
    private func updateMeasurement() {
        guard let mode = mode else { return }
        switch mode {
        case .length:
            let measurement = Measurement(value: calculateSketchLength(), unit: selectedLinearUnit)
            resultView.measurement = measurement
        case .area:
            let measurement = Measurement(value: calculateSketchArea(), unit: selectedAreaUnit)
            resultView.measurement = measurement
        case .feature:
            if let geometry = selectedGeometry {
                let measurement = Measurement(value: calculateMeasurement(of: geometry), unit: unit(for: geometry))
                resultView.measurement = measurement
            } else{
                resultView.helpText = "Tap a feature"
            }
        }
    }
    
    private func calculateSketchLength() -> Double{
        
        guard mapView?.sketchEditor?.isSketchValid == true, let geom = mapView?.sketchEditor?.geometry else{
            return 0
        }
        
        return calculateLength(of: geom)
    }
    
    private func calculateLength(of geom: AGSGeometry) -> Double{
        
        // if planar is very large then just return that, geodetic might take too long
        if let linearUnit = geom.spatialReference?.unit as? AGSLinearUnit{
            var planar = AGSGeometryEngine.length(of: geom)
            planar = linearUnit.convert(toMeters: planar)
            if planar > planarLengthMetersThreshold{
                let planarDisplay = AGSLinearUnit.meters().convert(planar, to: selectedLinearUnit)
                //`print("returning planar length... \(planar) sq meters")
                return planarDisplay
            }
        }
        
        // otherwise return geodetic value
        return AGSGeometryEngine.geodeticLength(of: geom, lengthUnit: selectedLinearUnit, curveType: geodeticCurveType)
    }
    
    private func calculateSketchArea() -> Double{
        
        guard mapView?.sketchEditor?.isSketchValid == true, let geom = mapView?.sketchEditor?.geometry else{
            return 0
        }
        
        return calculateArea(of: geom)
    }
    
    private func calculateArea(of geom: AGSGeometry) -> Double{
        
        // if planar is very large then just return that, geodetic might take too long
        if let linearUnit = geom.spatialReference?.unit as? AGSLinearUnit{
            let planar = AGSGeometryEngine.area(of: geom)
            if let planarMiles = linearUnit.toAreaUnit()?.convert(planar, to: AGSAreaUnit.squareMiles()),
                planarMiles > planarAreaSquareMilesThreshold{
                let planarDisplay = AGSAreaUnit.squareMiles().convert(planarMiles, to: selectedAreaUnit)
                //print("returning planar area... \(planarMiles) sq miles")
                return planarDisplay
            }
        }
        
        // otherwise return geodetic value
        return AGSGeometryEngine.geodeticArea(of: geom, areaUnit: selectedAreaUnit, curveType: geodeticCurveType)
    }
    
    private func calculateMeasurement(of geom: AGSGeometry) -> Double{
        switch geom.geometryType {
        case .polyline:
            return calculateLength(of: geom)
        case .polygon, .envelope:
            return calculateArea(of: geom)
        default:
            assertionFailure("unexpected geometry type")
            return 0
        }
    }
    
    private func unit(for geom: AGSGeometry) -> AGSUnit{
        
        switch geom.geometryType {
        case .polyline:
            return selectedLinearUnit
        case .polygon, .envelope:
            return selectedAreaUnit
        default:
            fatalError("unexpected geometry type")
        }
    }
    
    private func selectionSymbol(for geom: AGSGeometry) -> AGSSymbol?{
        
        switch geom.geometryType {
        case .polyline:
            return selectionLineSymbol
        case .polygon, .envelope:
            return selectionFillSymbol
        default:
            fatalError("unexpected geometry type")
        }
    }
    
    private var lastIdentify: AGSCancelable?
    
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint){
        
        lastIdentify?.cancel()
        
        lastIdentify = geoView.identifyGraphicsOverlays(atScreenPoint: screenPoint, tolerance: MeasureToolbar.identifyTolerance, returnPopupsOnly: false){ [weak self] results, error in
            
            guard let self = self else{
                return
            }
            
            if let error = error{
                guard (error as NSError).domain != NSCocoaErrorDomain && (error as NSError).code != NSUserCancelledError else{
                    return
                }
            }
            
            if let geom = self.firstOverlayPolyResult(in: results){
                // display graphic result
                self.select(geom: geom)
            }
            else{
                // otherwise identify layers to try to find a feature
                self.lastIdentify = geoView.identifyLayers(atScreenPoint: screenPoint, tolerance: MeasureToolbar.identifyTolerance, returnPopupsOnly: false){ [weak self] results, error in
                    
                    guard let self = self else{
                        return
                    }
                    
                    if let error = error{
                        guard (error as NSError).domain != NSCocoaErrorDomain && (error as NSError).code != NSUserCancelledError else{
                            return
                        }
                    }
                    
                    let geom = self.firstLayerPolyResult(in: results)
                    self.select(geom: geom)
                }
            }
            
        }
    }
    
    private func clearGeometrySelection(){
        selectionOverlay?.clearSelection()
        selectionOverlay?.graphics.removeAllObjects()
        selectedGeometry = nil
    }
    
    private func select(geom: AGSGeometry?){
        
        clearGeometrySelection()
        
        guard let geom = geom else{
            return
        }
        
        let graphic = AGSGraphic(geometry: geom, symbol: selectionSymbol(for: geom), attributes: nil)
        graphic.isSelected = true
        selectionOverlay?.graphics.add(graphic)
        
        selectedGeometry = geom
    }
    
    private func firstOverlayPolyResult(in identifyResults: [AGSIdentifyGraphicsOverlayResult]?) -> AGSGeometry?{
        
        guard let results = identifyResults else{
            return nil
        }
        
        for result in results{
            for ge in result.graphics{
                if ge.geometry?.geometryType == .polyline || ge.geometry?.geometryType == .polygon || ge.geometry?.geometryType == .envelope{
                    return ge.geometry!
                }
            }
        }
        return nil
    }
    
    private func firstLayerPolyResult(in identifyResults: [AGSIdentifyLayerResult]?) -> AGSGeometry?{
        
        guard let results = identifyResults else{
            return nil
        }
        
        for result in results{
            for ge in result.geoElements{
                if ge.geometry?.geometryType == .polyline || ge.geometry?.geometryType == .polygon || ge.geometry?.geometryType == .envelope{
                    return ge.geometry!
                }
            }
            if let subGeom = firstLayerPolyResult(in: result.sublayerResults){
                return subGeom
            }
        }
        return nil
    }
}

extension MeasureToolbar: UnitsViewControllerDelegate {
    public func unitsViewControllerDidCancel(_ unitsViewController: UnitsViewController) {
        unitsViewController.dismiss(animated: true)
    }
    
    public func unitsViewControllerDidSelectUnit(_ unitsViewController: UnitsViewController) {
        unitsViewController.dismiss(animated: true)
        switch unitsViewController.selectedUnit {
        case let linearUnit as AGSLinearUnit:
            selectedLinearUnit = linearUnit
        case let areaUnit as AGSAreaUnit:
            selectedAreaUnit = areaUnit
        default:
            fatalError("Unsupported unit type")
        }
    }
}

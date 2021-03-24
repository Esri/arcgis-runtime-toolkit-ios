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

public enum ScalebarUnits {
    case imperial
    case metric
    
    internal func baseUnits() -> AGSLinearUnit {
        return self == .imperial ? AGSLinearUnit.feet() : AGSLinearUnit.meters()
    }
    
    private static func multiplierAndMagnitudeForDistance(distance: Double) -> (multiplier: Double, magnitude: Double) {
        // get multiplier
        
        let magnitude = pow(10, floor(log10(distance)))
        let residual = distance / Double(magnitude)
        let multiplier: Double = ScalebarUnits.roundNumberMultipliers.filter { $0 <= residual }.last ?? 0
        return (multiplier, magnitude)
    }
    
    internal func closestDistanceWithoutGoingOver(to distance: Double, units: AGSLinearUnit) -> Double {
        let mm = ScalebarUnits.multiplierAndMagnitudeForDistance(distance: distance)
        let roundNumber = mm.multiplier * mm.magnitude
        
        // because feet and miles are not relationally multiples of 10 with each other,
        // we have to convert to miles if we are dealing in miles
        if units == AGSLinearUnit.feet() {
            let displayUnits = linearUnitsForDistance(distance: roundNumber)
            if units != displayUnits {
                let displayDistance = closestDistanceWithoutGoingOver(to: units.convert(distance, to: displayUnits), units: displayUnits)
                return displayUnits.convert(displayDistance, to: units)
            }
        }
        
        return roundNumber
    }
    
    // this table must begin with 1 and end with 10
    private static let roundNumberMultipliers: [Double] = [1, 1.2, 1.25, 1.5, 1.75, 2, 2.4, 2.5, 3, 3.75, 4, 5, 6, 7.5, 8, 9, 10]
    
    // swiftlint:disable cyclomatic_complexity
    private static func segmentOptionsForMultiplier(multiplier: Double) -> [Int] {
        switch multiplier {
        case 1:
            return [1, 2, 4, 5]
        case 1.2:
            return [1, 2, 3, 4]
        case 1.25:
            return [1, 2]
        case 1.5:
            return [1, 2, 3, 5]
        case 1.75:
            return [1, 2]
        case 2:
            return [1, 2, 4, 5]
        case 2.4:
            return [1, 2, 3]
        case 2.5:
            return [1, 2, 5]
        case 3:
            return [1, 2, 3]
        case 3.75:
            return [1, 3]
        case 4:
            return [1, 2, 4]
        case 5:
            return [1, 2, 5]
        case 6:
            return [1, 2, 3]
        case 7.5:
            return [1, 2]
        case 8:
            return [1, 2, 4]
        case 9:
            return [1, 2, 3]
        case 10:
            return [1, 2, 5]
        default:
            return [1]
        }
    }
    // swiftlint:enable cyclomatic_complexity

    internal static func numSegmentsForDistance(distance: Double, maxNumSegments: Int) -> Int {
        // this function returns the best number of segments so that we get relatively round
        // numbers when the distance is divided up.
        
        let mm = multiplierAndMagnitudeForDistance(distance: distance)
        let options = segmentOptionsForMultiplier(multiplier: mm.multiplier)
        let num = options.filter { $0 <= maxNumSegments }.last ?? 1
        return num
    }
    
    internal func linearUnitsForDistance(distance: Double) -> AGSLinearUnit {
        switch self {
        case .imperial:
            
            if distance >= 2640 {
                return AGSLinearUnit.miles()
            }
            return AGSLinearUnit.feet()
            
        case .metric:
            
            if distance >= 1000 {
                return AGSLinearUnit.kilometers()
            }
            return AGSLinearUnit.meters()
        }
    }
}

public enum ScalebarStyle {
    case line
    case bar
    case graduatedLine
    case alternatingBar
    case dualUnitLine
    
    fileprivate func rendererForScalebar(scalebar: Scalebar) -> ScalebarRenderer {
        switch self {
        case .line:
            return ScalebarLineStyleRenderer(scalebar: scalebar)
        case .bar:
            return ScalebarBarStyleRenderer(scalebar: scalebar)
        case .graduatedLine:
            return ScalebarGraduatedLineStyleRenderer(scalebar: scalebar)
        case .alternatingBar:
            return ScalebarAlternatingBarStyleRenderer(scalebar: scalebar)
        case .dualUnitLine:
            return ScalebarDualUnitLineStyleRenderer(scalebar: scalebar)
        }
    }
}

public enum ScalebarAlignment {
    case left
    case right
    case center
}

public class Scalebar: UIView {
    //
    // public properties
    
    public var units: ScalebarUnits = .imperial {
        didSet {
            updateScaleDisplay(forceRedraw: true)
        }
    }
    
    public var style: ScalebarStyle = .line {
        didSet {
            renderer = style.rendererForScalebar(scalebar: self)
            updateScaleDisplay(forceRedraw: true)
        }
    }
    
    @IBInspectable public var fillColor: UIColor? = UIColor.lightGray.withAlphaComponent(0.5) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable public var alternateFillColor: UIColor? = UIColor.black {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable public var lineColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable public var shadowColor: UIColor? = UIColor.black.withAlphaComponent(0.65) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable public var textColor: UIColor? = UIColor.black {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable  public var textShadowColor: UIColor? = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Set this to a value greater than 0 if you don't specify constraints for width and want to rely
    // on intrinsic content size for the width when using autolayout. Only applicable for autolayout.
    @IBInspectable public var maximumIntrinsicWidth: CGFloat = 0 {
        didSet {
            // this will invalidate the intrinsicContentSize and also redraw
            updateScaleDisplay(forceRedraw: true)
        }
    }
    
    public var alignment: ScalebarAlignment = .left {
        didSet {
            updateScaleDisplay(forceRedraw: true)
        }
    }
    
    // allow user to turn off/on geodetic calculations
    public var useGeodeticCalculations = true
    
    public var mapView: AGSMapView? {
        didSet {
            unbindFromMapView(mapView: oldValue)
            bindToMapView(mapView: mapView)
            updateScaleDisplay(forceRedraw: true)
        }
    }
    
    public var font = UIFont.systemFont(ofSize: 9.0, weight: UIFont.Weight.semibold) {
        didSet {
            recalculateFontProperties()
            updateScaleDisplay(forceRedraw: true)
        }
    }
    
    //
    // private properties
    
    private static let geodeticCurveType: AGSGeodeticCurveType = .geodesic
    
    //
    // internal statics
    
    internal static let labelYPad: CGFloat = 2.0
    internal static let labelXPad: CGFloat = 4.0
    internal static let tickHeight: CGFloat = 6.0
    internal static let tick2Height: CGFloat = 4.5
    internal static let notchHeight: CGFloat = 6.0
    internal static var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.formatterBehavior = .behavior10_4
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 0
        return numberFormatter
    }()
    
    internal static let showFrameDebugColors = false
    internal static let lineCap = CGLineCap.round
    
    internal var fontHeight: CGFloat = 0
    internal var zeroStringWidth: CGFloat = 0
    internal var maxRightUnitsPad: CGFloat = 0
    
    private func recalculateFontProperties() {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        let zeroText = "0"
        zeroStringWidth = zeroText.size(withAttributes: attributes).width
        
        let fontHeightText = "Ay"
        fontHeight = fontHeightText.size(withAttributes: attributes).height
        
        let unitsMaxText = " km"
        maxRightUnitsPad = unitsMaxText.size(withAttributes: attributes).width
    }
    
    // set a minScale if you only want the scalebar to appear when you reach a large enough scale
    // maybe something like 10_000_000. This could be useful because the scalebar is really only
    // accurate for the center of the map on smaller scales (when zoomed way out).
    // A minScale of 0 means it will always be visible
    private let minScale: Double = 0
    private var updateCoalescer: Coalescer?

    private var renderer: ScalebarRenderer?
    
    deinit {
        unbindFromMapView(mapView: mapView)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInitialization()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    public required init(mapView: AGSMapView) {
        super.init(frame: CGRect.zero)
        sharedInitialization()
        self.mapView = mapView
        // because didSet doesn't happen in constructors
        bindToMapView(mapView: mapView)
    }
    
    private func sharedInitialization() {
        self.updateCoalescer = Coalescer(dispatchQueue: DispatchQueue.main, interval: DispatchTimeInterval.milliseconds(500), action: updateScaleDisplayIfNecessary)
        
        self.isUserInteractionEnabled = false
        self.isOpaque = false
        
        self.units = NSLocale.current.usesMetricSystem ? .metric : .imperial
        
        renderer = style.rendererForScalebar(scalebar: self)
        recalculateFontProperties()
    }
    
    private var mapObservation: NSKeyValueObservation?
    private var visibleAreaObservation: NSKeyValueObservation?
    
    private func bindToMapView(mapView: AGSMapView?) {
        mapObservation = mapView?.observe(\.map, options: .new) {[weak self] _, _ in
            self?.updateScaleDisplay(forceRedraw: false)
        }
        visibleAreaObservation = mapView?.observe(\.visibleArea, options: .new) { [weak self] _, _ in
            // since we get updates so often, we don't need to redraw that often
            // so use the coalescer to filter the events on a time interval
            self?.updateCoalescer?.ping()
        }
    }
    
    private func unbindFromMapView(mapView: AGSMapView?) {
        // invalidate observations and set to nil
        mapObservation?.invalidate()
        mapObservation = nil
        visibleAreaObservation?.invalidate()
        visibleAreaObservation = nil
    }
    
    private func updateScaleDisplayIfNecessary() {
        updateScaleDisplay(forceRedraw: false)
    }
    
    // swiftlint:disable cyclomatic_complexity
    private func updateScaleDisplay(forceRedraw: Bool) {
        guard var renderer = renderer else {
            // this should never happen, should always have a renderer
            setNeedsDisplay()
            return
        }
        
        guard let mapView = mapView else {
            renderer.currentScaleDisplay = nil
            setNeedsDisplay()
            return
        }
        
        guard mapView.map != nil else {
            renderer.currentScaleDisplay = nil
            setNeedsDisplay()
            return
        }
        
        guard let sr = mapView.spatialReference else {
            renderer.currentScaleDisplay = nil
            setNeedsDisplay()
            return
        }
        
        guard let visibleArea = mapView.visibleArea else {
            renderer.currentScaleDisplay = nil
            setNeedsDisplay()
            return
        }
        
        // print("current scale: \(mapView.mapScale)")
        
        guard minScale <= 0 || mapView.mapScale < minScale else {
            // print("current scale: \(mapView.mapScale), minScale \(minScale)")
            renderer.currentScaleDisplay = nil
            setNeedsDisplay()
            return
        }
        
        let totalWidthAvailable = (!translatesAutoresizingMaskIntoConstraints && maximumIntrinsicWidth > 0) ? maximumIntrinsicWidth : bounds.width
        let maxLength = renderer.availableLineDisplayLength(totalDisplayWidth: totalWidthAvailable)
        
        // ScaleDisplay properties
        let mapScale = mapView.mapScale
        let unitsPerPoint = mapView.unitsPerPoint
        let lineMapLength: Double
        let displayUnit: AGSLinearUnit
        let mapCenter = visibleArea.extent.center
        let lineDisplayLength: CGFloat
        
        // bail early if we can because the last time we drew was good
        if let csd = renderer.currentScaleDisplay, forceRedraw == false {
            var needsRedraw = false
            if csd.mapScale != mapScale { needsRedraw = true }
            let dependsOnMapCenter = sr.unit is AGSAngularUnit || useGeodeticCalculations
            if dependsOnMapCenter && !mapCenter.isEqual(to: csd.mapCenter) { needsRedraw = true }
            if !needsRedraw {
                // no need to redraw - nothing significant changed
                return
            }
        }
        
        if useGeodeticCalculations || sr.unit is AGSAngularUnit {
            let maxLengthPlanar = unitsPerPoint * Double(maxLength)
            let p1 = AGSPoint(x: mapCenter.x - (maxLengthPlanar * 0.5), y: mapCenter.y, spatialReference: sr)
            let p2 = AGSPoint(x: mapCenter.x + (maxLengthPlanar * 0.5), y: mapCenter.y, spatialReference: sr)
            let polyline = AGSPolyline(points: [p1, p2])
            let baseUnits = units.baseUnits()
            let maxLengthGeodetic = AGSGeometryEngine.geodeticLength(of: polyline, lengthUnit: baseUnits, curveType: Scalebar.geodeticCurveType)
            let roundNumberDistance = units.closestDistanceWithoutGoingOver(to: maxLengthGeodetic, units: baseUnits)
            let planarToGeodeticFactor = maxLengthPlanar / maxLengthGeodetic
            lineDisplayLength = CGFloat( (roundNumberDistance * planarToGeodeticFactor) / unitsPerPoint )
            displayUnit = units.linearUnitsForDistance(distance: roundNumberDistance)
            lineMapLength = baseUnits.convert(roundNumberDistance, to: displayUnit)
        } else {
            guard let srUnit = sr.unit as? AGSLinearUnit else {
                renderer.currentScaleDisplay = nil
                setNeedsDisplay()
                return
            }
            
            let unitsPerPoint = mapView.unitsPerPoint
            let baseUnits = units.baseUnits()
            let lenAvail = srUnit.convert(unitsPerPoint * Double(maxLength), to: baseUnits)
            let closestLen = units.closestDistanceWithoutGoingOver(to: lenAvail, units: baseUnits)
            lineDisplayLength = CGFloat(baseUnits.convert(closestLen, to: srUnit) / unitsPerPoint)
            displayUnit = units.linearUnitsForDistance(distance: closestLen)
            lineMapLength = baseUnits.convert(closestLen, to: displayUnit)
        }
        
        guard lineDisplayLength.isFinite, !lineDisplayLength.isNaN else {
            renderer.currentScaleDisplay = nil
            setNeedsDisplay()
            return
        }
        
        let mapLengthString = Scalebar.numberFormatter.string(from: NSNumber(value: lineMapLength)) ?? ""
        renderer.currentScaleDisplay = ScaleDisplay(mapScale: mapScale, unitsPerPoint: unitsPerPoint, lineMapLength: lineMapLength, displayUnit: displayUnit, lineDisplayLength: lineDisplayLength, mapCenter: mapCenter, mapLengthString: mapLengthString)
        
        // print("geodetic: \(useGeodeticCalculations), lineDisplayLength: \(numberFormatter.string(from: lineDisplayLength as NSNumber)!), mapLength: \(lineMapLength) \(displayUnit.abbreviation))")
        
        // invalidate intrinsic content size
        invalidateIntrinsicContentSize()
        
        // tell view we need to redraw
        setNeedsDisplay()
    }
    // swiftlint:enable cyclomatic_complexity

    override public var intrinsicContentSize: CGSize {
        if let renderer = renderer {
            if maximumIntrinsicWidth > 0 {
                return CGSize(width: renderer.currentMaxDisplayWidth, height: renderer.displayHeight)
            } else {
                return CGSize(width: UIView.noIntrinsicMetric, height: renderer.displayHeight)
            }
        } else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }
    
    private func offsetRectForDisplaySize(displaySize: CGSize) -> CGRect {
        // center on y axis
        let offsetY = (bounds.height - displaySize.height) / 2
        
        let displayRect = CGRect(x: 0, y: 0, width: displaySize.width, height: displaySize.height)
        
        switch alignment {
        case .left:
            return displayRect.offsetBy(dx: 0, dy: offsetY)
        case .right:
            let offsetX = bounds.width - displaySize.width
            return displayRect.offsetBy(dx: offsetX, dy: offsetY)
        case .center:
            let offsetX = (bounds.width - displaySize.width) / 2.0
            return displayRect.offsetBy(dx: offsetX, dy: offsetY)
        }
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let renderer = self.renderer, renderer.currentScaleDisplay != nil else {
            return
        }
        
        let displaySize = CGSize(width: renderer.currentMaxDisplayWidth, height: renderer.displayHeight)
        
        let odr = offsetRectForDisplaySize(displaySize: displaySize)
        
        guard !odr.isEmpty else {
            return
        }
        
        if Scalebar.showFrameDebugColors, let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            
            context.setFillColor(UIColor.yellow.cgColor)
            context.fill(bounds)
            
            context.setLineWidth(1.0)
            context.setStrokeColor(UIColor.blue.cgColor)
            context.stroke(odr)
            
            context.restoreGState()
        }
        
        renderer.draw(rect: odr)
    }
    
    private func calculateDisplaySize() -> CGSize {
        if let renderer = renderer {
            let displaySize = CGSize(width: renderer.currentMaxDisplayWidth, height: renderer.displayHeight)
            return displaySize
        } else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }
}

internal struct ScaleDisplay {
    var mapScale: Double = 0
    var unitsPerPoint: Double = 0
    var lineMapLength: Double = 0
    var displayUnit: AGSLinearUnit
    var lineDisplayLength: CGFloat = 0
    var mapCenter: AGSPoint
    var mapLengthString: String
}

internal struct SegmentInfo {
    var index: Int
    var segmentScreenLength: CGFloat
    var xOffset: CGFloat
    var segmentMapLength: Double
    var text: String
    var textWidth: CGFloat
}

internal protocol ScalebarRenderer {
    var scalebar: Scalebar? { get }
    var currentScaleDisplay: ScaleDisplay? { get set }
    var displayHeight: CGFloat { get }
    var currentMaxDisplayWidth: CGFloat { get }
    
    init(scalebar: Scalebar)
    
    func availableLineDisplayLength(totalDisplayWidth: CGFloat) -> CGFloat
    func draw(rect: CGRect)
}

internal extension ScalebarRenderer {
    var shadowOffset: CGPoint {
        return CGPoint(x: 0.5, y: 0.5)
    }
    
    var lineWidth: CGFloat {
        return 2
    }
    
    var halfLineWidth: CGFloat {
        return 1
    }
    
    func calculateSegmentInfos() -> [SegmentInfo]? {
        guard let scaleDisplay = currentScaleDisplay, let scalebar = scalebar else {
            return nil
        }
        
        let lineDisplayLength = scaleDisplay.lineDisplayLength
        
        // use a string with at least a few characters in case the number string only has 1
        // the dividers will be decimal values and we want to make sure they all fit
        // very basic hueristics...
        let minSegmentTestString = (scaleDisplay.mapLengthString.count > 3) ? scaleDisplay.mapLengthString : "9.9"
        // use 1.5 because the last segment, the text is right justified insted of center, which makes it harder to squeeze text in
        let minSegmentWidth = (minSegmentTestString.size(withAttributes: [.font: scalebar.font]).width * 1.5) + (Scalebar.labelXPad * 2)
        var maxNumSegments = Int(lineDisplayLength / minSegmentWidth)
        maxNumSegments = min(maxNumSegments, 4) // cap it at 4
        let numSegments: Int = ScalebarUnits.numSegmentsForDistance(distance: scaleDisplay.lineMapLength, maxNumSegments: maxNumSegments)
        
        let segmentScreenLength: CGFloat = (lineDisplayLength / CGFloat(numSegments))
        
        var currSegmentX: CGFloat = 0
        
        var segmentInfos = [SegmentInfo]()
        
        for index in 0..<numSegments {
            currSegmentX += segmentScreenLength
            let segmentMapLength = Double((segmentScreenLength * CGFloat(index + 1)) / lineDisplayLength) * scaleDisplay.lineMapLength
            let segmentText = Scalebar.numberFormatter.string(from: NSNumber(value: segmentMapLength)) ?? ""
            let segmentTextWidth = segmentText.size(withAttributes: [.font: scalebar.font]).width
            
            let segmentInfo = SegmentInfo(index: index, segmentScreenLength: segmentScreenLength, xOffset: currSegmentX, segmentMapLength: segmentMapLength, text: segmentText, textWidth: segmentTextWidth)
            
            segmentInfos.append(segmentInfo)
        }
        
        return segmentInfos
    }
    
    func drawText(text: String, frame: CGRect, alignment: NSTextAlignment) {
        guard let scalebar = scalebar, let textColor = scalebar.textColor else {
            return
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        
        // draw text shadow
        if let shadowColor = scalebar.textShadowColor {
            let shadowAttrs: [NSAttributedString.Key: Any] = [
                .font: scalebar.font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: shadowColor
            ]
            
            let shadowFrame = frame.offsetBy(dx: shadowOffset.x, dy: shadowOffset.y)
            
            text.draw(with: shadowFrame, options: .usesLineFragmentOrigin, attributes: shadowAttrs, context: nil)
        }
        
        // draw text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: scalebar.font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor
        ]
        
        text.draw(with: frame, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    func drawSegmentsText(segmentInfos: [SegmentInfo], scaleDisplay: ScaleDisplay, startingX: CGFloat, textY: CGFloat) {
        guard let scalebar = scalebar else {
            return
        }
        
        // the text on the ends need to be offset such that they line up with the edge of the line
        // because they are left/right justified
        let endOffset = halfLineWidth
        
        let zeroTextFrame = CGRect(x: startingX - endOffset,
                                   y: textY,
                                   width: scalebar.zeroStringWidth,
                                   height: scalebar.fontHeight)
        
        self.drawText(text: "0", frame: zeroTextFrame, alignment: .left)
        
        // draw segment text
        for si in segmentInfos {
            if si.index == segmentInfos.last?.index {
                // last segment text
                
                let segmentX = startingX + si.xOffset - si.textWidth + endOffset
                let segmentTextFrame = CGRect(x: segmentX,
                                              y: textY,
                                              width: si.textWidth,
                                              height: scalebar.fontHeight)
                
                self.drawText(text: si.text, frame: segmentTextFrame, alignment: .right)
                
                // draw units off the end
                
                let unitsText = " \(scaleDisplay.displayUnit.abbreviation)"
                let unitsTextWidth = unitsText.size(withAttributes: [.font: scalebar.font]).width
                
                let unitsTextFrame = CGRect(x: segmentTextFrame.maxX,
                                            y: textY,
                                            width: unitsTextWidth,
                                            height: scalebar.fontHeight)
                
                self.drawText(text: unitsText, frame: unitsTextFrame, alignment: .right)
            } else {
                // all but last segment text
                
                let segmentX = startingX + si.xOffset
                let segmentTextFrame = CGRect(x: segmentX - (si.textWidth / 2),
                                              y: textY,
                                              width: si.textWidth,
                                              height: scalebar.fontHeight)
                
                self.drawText(text: si.text, frame: segmentTextFrame, alignment: .center)
            }
        }
    }
}

internal class ScalebarLineStyleRenderer: ScalebarRenderer {
    weak var scalebar: Scalebar?
    
    required init(scalebar: Scalebar) {
        self.scalebar = scalebar
    }
    
    var currentScaleDisplay: ScaleDisplay?
    
    var displayHeight: CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return halfLineWidth + Scalebar.tickHeight + Scalebar.labelYPad + scalebar.fontHeight + shadowOffset.y
    }
    
    var currentMaxDisplayWidth: CGFloat {
        guard let scaleDisplay = currentScaleDisplay else {
            return 0
        }
        return halfLineWidth + scaleDisplay.lineDisplayLength + halfLineWidth + shadowOffset.x
    }
    
    func availableLineDisplayLength(totalDisplayWidth: CGFloat) -> CGFloat {
        return totalDisplayWidth - lineWidth
    }
    
    func draw(rect: CGRect) {
        guard let scaleDisplay = currentScaleDisplay else {
            return
        }
        
        guard let scalebar = self.scalebar else {
            return
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        // save context
        context.saveGState()
        
        // Some vars
        let x = rect.origin.x
        let y = rect.origin.y
        let lineScreenLength = scaleDisplay.lineDisplayLength
        
        let path = CGMutablePath()
        
        // set path for line style
        
        /*
         |____________________|
                 200km
         */
        
        let lineX = x + halfLineWidth
        let lineTop = y + halfLineWidth
        let lineBottom = lineTop + Scalebar.tickHeight
        
        path.move(to: CGPoint(x: lineX, y: lineTop))
        path.addLine(to: CGPoint(x: lineX, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineTop))
        
        //
        // draw paths
        
        context.setLineCap(Scalebar.lineCap)
        context.setLineJoin(CGLineJoin.bevel)
        
        if let shadowColor = scalebar.shadowColor {
            var t = CGAffineTransform(translationX: shadowOffset.x, y: shadowOffset.y)
            if let shadowPath = path.copy(using: &t) {
                context.setLineWidth(lineWidth)
                context.setStrokeColor(shadowColor.cgColor)
                context.addPath(shadowPath)
                context.drawPath(using: .stroke)
            }
        }
        
        // draw path
        context.setLineWidth(lineWidth)
        context.setStrokeColor(scalebar.lineColor.cgColor)
        context.addPath(path)
        context.drawPath(using: .stroke)
        
        // draw text
        let text = String(format: "%@ %@", scaleDisplay.mapLengthString, scaleDisplay.displayUnit.abbreviation)
        
        let textFrame = CGRect(x: x,
                               y: lineBottom + Scalebar.labelYPad,
                               width: rect.width,
                               height: scalebar.fontHeight)
        
        self.drawText(text: text, frame: textFrame, alignment: .center)
        
        // reset the state
        context.restoreGState()
    }
}

internal class ScalebarGraduatedLineStyleRenderer: ScalebarRenderer {
    weak var scalebar: Scalebar?
    
    required init(scalebar: Scalebar) {
        self.scalebar = scalebar
    }
    
    var currentScaleDisplay: ScaleDisplay?
    
    var displayHeight: CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return halfLineWidth + Scalebar.tickHeight + Scalebar.labelYPad + scalebar.fontHeight + shadowOffset.y
    }
    
    var currentMaxDisplayWidth: CGFloat {
        guard let scalebar = scalebar, let scaleDisplay = currentScaleDisplay else {
            return 0
        }
        return halfLineWidth + scaleDisplay.lineDisplayLength + halfLineWidth + scalebar.maxRightUnitsPad + shadowOffset.x
    }
    
    func availableLineDisplayLength(totalDisplayWidth: CGFloat) -> CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return totalDisplayWidth - halfLineWidth - scalebar.maxRightUnitsPad
    }
    
    func draw(rect: CGRect) {
        guard let scaleDisplay = currentScaleDisplay else {
            return
        }
        
        guard let scalebar = self.scalebar else {
            return
        }
        
        guard let segmentInfos = calculateSegmentInfos() else {
            return
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        // save context
        context.saveGState()
        
        // Some vars
        let x = rect.origin.x
        let y = rect.origin.y
        let lineScreenLength = scaleDisplay.lineDisplayLength
        
        let path = CGMutablePath()
        
        // setup path for graduated line style
        
        /*
         |_________|__________|
         0        100       200km
         */
        
        let lineTop = y + halfLineWidth
        let lineBottom = lineTop + Scalebar.tickHeight
        let lineX = x + halfLineWidth
        
        path.move(to: CGPoint(x: lineX, y: lineTop))
        path.addLine(to: CGPoint(x: lineX, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineTop))
        
        // draw segment ticks
        for si in segmentInfos {
            if si.index == segmentInfos.last?.index {
                // skip last segment
                continue
            }
            let segmentX = lineX + si.xOffset
            path.move(to: CGPoint(x: segmentX, y: lineBottom))
            path.addLine(to: CGPoint(x: segmentX, y: lineBottom - Scalebar.tick2Height))
        }
        
        //
        // draw paths
        
        context.setLineCap(Scalebar.lineCap)
        context.setLineJoin(CGLineJoin.bevel)
        
        if let shadowColor = scalebar.shadowColor {
            var t = CGAffineTransform(translationX: shadowOffset.x, y: shadowOffset.y)
            if let shadowPath = path.copy(using: &t) {
                context.setLineWidth(lineWidth)
                context.setStrokeColor(shadowColor.cgColor)
                context.addPath(shadowPath)
                context.drawPath(using: .stroke)
            }
        }
        
        // draw path
        context.setLineWidth(lineWidth)
        context.setStrokeColor(scalebar.lineColor.cgColor)
        context.addPath(path)
        context.drawPath(using: .stroke)
        
        //
        // draw text
        
        let textY = lineBottom + Scalebar.labelYPad
        drawSegmentsText(segmentInfos: segmentInfos, scaleDisplay: scaleDisplay, startingX: lineX, textY: textY)
        
        // reset the state
        context.restoreGState()
    }
}

internal class ScalebarBarStyleRenderer: ScalebarRenderer {
    weak var scalebar: Scalebar?
    
    required init(scalebar: Scalebar) {
        self.scalebar = scalebar
    }
    
    var currentScaleDisplay: ScaleDisplay?
    
    var displayHeight: CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return Scalebar.notchHeight + Scalebar.labelYPad + scalebar.fontHeight + shadowOffset.y
    }
    
    var currentMaxDisplayWidth: CGFloat {
        guard let scaleDisplay = currentScaleDisplay else {
            return 0
        }
        return halfLineWidth + scaleDisplay.lineDisplayLength + halfLineWidth + shadowOffset.x
    }
    
    func availableLineDisplayLength(totalDisplayWidth: CGFloat) -> CGFloat {
        return totalDisplayWidth - lineWidth
    }
    
    func draw(rect: CGRect) {
        guard let scaleDisplay = currentScaleDisplay else {
            return
        }
        
        guard let scalebar = self.scalebar else {
            return
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        // save context
        context.saveGState()
        
        // Some vars
        let x = rect.origin.x
        let y = rect.origin.y
        let lineScreenLength = scaleDisplay.lineDisplayLength
        
        let path = CGMutablePath()
        
        // set path for bar style
        /*
         ===================
               200km
         */
        
        let lineX = x + halfLineWidth
        let lineTop = y + halfLineWidth
        let lineBottom = lineTop + Scalebar.notchHeight
        
        path.move(to: CGPoint(x: lineX, y: lineTop))
        path.addLine(to: CGPoint(x: lineX, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineTop))
        path.closeSubpath()
        
        //
        // draw paths
        
        context.setLineCap(Scalebar.lineCap)
        context.setLineJoin(CGLineJoin.bevel)
        
        if let shadowColor = scalebar.shadowColor {
            var t = CGAffineTransform(translationX: shadowOffset.x, y: shadowOffset.y)
            if let shadowPath = path.copy(using: &t) {
                context.setLineWidth(lineWidth)
                context.setStrokeColor(shadowColor.cgColor)
                context.addPath(shadowPath)
                context.drawPath(using: .stroke)
            }
        }
        
        if let fillColor = scalebar.fillColor {
            context.setFillColor(fillColor.cgColor)
            context.addPath(path)
            context.drawPath(using: .fill)
        }
        
        // draw path
        context.setLineWidth(lineWidth)
        context.setStrokeColor(scalebar.lineColor.cgColor)
        context.addPath(path)
        context.drawPath(using: .stroke)
        
        // draw text
        let text = String(format: "%@ %@", scaleDisplay.mapLengthString, scaleDisplay.displayUnit.abbreviation)
        
        let textFrame = CGRect(x: x,
                               y: lineBottom + Scalebar.labelYPad,
                               width: rect.width,
                               height: scalebar.fontHeight)
        
        self.drawText(text: text, frame: textFrame, alignment: .center)
        
        // reset the state
        context.restoreGState()
    }
}

internal class ScalebarAlternatingBarStyleRenderer: ScalebarRenderer {
    weak var scalebar: Scalebar?
    
    required init(scalebar: Scalebar) {
        self.scalebar = scalebar
    }
    
    var currentScaleDisplay: ScaleDisplay?
    
    var displayHeight: CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return halfLineWidth + Scalebar.notchHeight + Scalebar.labelYPad + scalebar.fontHeight + shadowOffset.y
    }
    
    var currentMaxDisplayWidth: CGFloat {
        guard let scalebar = scalebar, let scaleDisplay = currentScaleDisplay else {
            return 0
        }
        return halfLineWidth + scaleDisplay.lineDisplayLength + halfLineWidth + scalebar.maxRightUnitsPad + shadowOffset.x
    }
    
    // can change this if you want to see quarter graduation
    private let showQuarters = false
    
    func availableLineDisplayLength(totalDisplayWidth: CGFloat) -> CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return totalDisplayWidth - halfLineWidth - scalebar.maxRightUnitsPad
    }
    
    // swiftlint:disable cyclomatic_complexity
    func draw(rect: CGRect) {
        guard let scaleDisplay = currentScaleDisplay else {
            return
        }
        
        guard let scalebar = self.scalebar else {
            return
        }
        
        guard let segmentInfos = calculateSegmentInfos() else {
            return
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        // save context
        context.saveGState()
        
        // Some vars
        let x = rect.origin.x
        let y = rect.origin.y
        let lineScreenLength = scaleDisplay.lineDisplayLength
        
        let pathStroke = CGMutablePath()
        
        // set path for bar style
        /*
         =========~~~~~~~~~~
         0      100      200km
         */
        
        let lineTop = y + halfLineWidth
        let lineBottom = lineTop + Scalebar.notchHeight
        let lineX = x + halfLineWidth
        
        // create path for strokes
        
        // main rectangle
        pathStroke.move(to: CGPoint(x: lineX, y: lineTop))
        pathStroke.addLine(to: CGPoint(x: lineX, y: lineBottom))
        pathStroke.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineBottom))
        pathStroke.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineTop))
        pathStroke.closeSubpath()
        
        // add all segment ticks
        for si in segmentInfos {
            if si.index == segmentInfos.last?.index {
                // skip last segment
                continue
            }
            let segmentX = lineX + si.xOffset
            pathStroke.move(to: CGPoint(x: segmentX, y: lineBottom))
            pathStroke.addLine(to: CGPoint(x: segmentX, y: lineTop))
        }
        
        // add paths for filling in colors
        
        let fillPath1 = CGMutablePath()
        let fillPath2 = CGMutablePath()
        
        var lastPathX = lineX
        
        for si in segmentInfos {
            let fillPath = (si.index % 2) == 0 ? fillPath2 : fillPath1
            
            let pathX = lineX + si.xOffset
            
            fillPath.move(to: CGPoint(x: lastPathX, y: lineTop))
            fillPath.addLine(to: CGPoint(x: lastPathX, y: lineBottom))
            fillPath.addLine(to: CGPoint(x: pathX, y: lineBottom))
            fillPath.addLine(to: CGPoint(x: pathX, y: lineTop))
            fillPath.closeSubpath()
            
            lastPathX = pathX
        }
        
        //
        // draw paths
        
        context.setLineCap(Scalebar.lineCap)
        context.setLineJoin(CGLineJoin.bevel)
        
        // stroke shadow
        if let shadowColor = scalebar.shadowColor {
            var t = CGAffineTransform(translationX: shadowOffset.x, y: shadowOffset.y)
            if let shadowPath = pathStroke.copy(using: &t) {
                context.setLineWidth(lineWidth)
                context.setStrokeColor(shadowColor.cgColor)
                context.addPath(shadowPath)
                context.drawPath(using: .stroke)
            }
        }
        
        // fill in odd segments
        if let fillColor = scalebar.fillColor {
            context.setFillColor(fillColor.cgColor)
            context.addPath(fillPath1)
            context.drawPath(using: .fill)
        }
        
        // fill in even segments
        if let alternateFillColor = scalebar.alternateFillColor {
            context.setFillColor(alternateFillColor.cgColor)
            context.addPath(fillPath2)
            context.drawPath(using: .fill)
        }
        
        // draw paths strokes
        context.setLineWidth(lineWidth)
        context.setStrokeColor(scalebar.lineColor.cgColor)
        context.addPath(pathStroke)
        context.drawPath(using: .stroke)
        
        //
        // draw text
        
        let textY = lineBottom + Scalebar.labelYPad
        drawSegmentsText(segmentInfos: segmentInfos, scaleDisplay: scaleDisplay, startingX: lineX, textY: textY)
        
        // reset the state
        context.restoreGState()
    }
    // swiftlint:enable cyclomatic_complexity
}

internal class ScalebarDualUnitLineStyleRenderer: ScalebarRenderer {
    weak var scalebar: Scalebar?
    
    required init(scalebar: Scalebar) {
        self.scalebar = scalebar
    }
    
    var currentScaleDisplay: ScaleDisplay?
    
    var displayHeight: CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return scalebar.fontHeight + Scalebar.labelYPad + Scalebar.tick2Height + Scalebar.tick2Height + Scalebar.labelYPad + scalebar.fontHeight + shadowOffset.y
    }
    
    var currentMaxDisplayWidth: CGFloat {
        guard let scalebar = scalebar, let scaleDisplay = currentScaleDisplay else {
            return 0
        }
        return halfLineWidth + scaleDisplay.lineDisplayLength + halfLineWidth + scalebar.maxRightUnitsPad + shadowOffset.x
    }
    
    func availableLineDisplayLength(totalDisplayWidth: CGFloat) -> CGFloat {
        guard let scalebar = scalebar else { return 0 }
        return totalDisplayWidth - halfLineWidth - scalebar.maxRightUnitsPad
    }
    
    func draw(rect: CGRect) {
        guard let scaleDisplay = currentScaleDisplay else {
            return
        }
        
        guard let scalebar = self.scalebar else {
            return
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        // save context
        context.saveGState()
        
        // Some vars
        let x = rect.origin.x
        let y = rect.origin.y
        let lineScreenLength = scaleDisplay.lineDisplayLength
        
        let path = CGMutablePath()
        
        // setup path for dual unit line style
        
        /*
                           60 km
         |___________________|
         |              |
                        30 mi
         */
        
        let lineTop = y + scalebar.fontHeight + Scalebar.labelYPad
        let lineY = lineTop + Scalebar.tick2Height
        let lineBottom = lineY + Scalebar.tick2Height
        let lineX = x + halfLineWidth
        
        // top unit line
        path.move(to: CGPoint(x: lineX, y: lineTop))
        path.addLine(to: CGPoint(x: lineX, y: lineBottom))
        path.move(to: CGPoint(x: lineX, y: lineY))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineY))
        path.addLine(to: CGPoint(x: lineX + lineScreenLength, y: lineTop))
        
        // bottom unit line
        let otherUnit = (scalebar.units == ScalebarUnits.imperial) ? ScalebarUnits.metric : ScalebarUnits.imperial
        let otherMapBaseLength = scaleDisplay.displayUnit.convert(scaleDisplay.lineMapLength, to: otherUnit.baseUnits())
        let otherClosestBaseLength = otherUnit.closestDistanceWithoutGoingOver(to: otherMapBaseLength, units: otherUnit.baseUnits())
        let otherDisplayUnits = otherUnit.linearUnitsForDistance(distance: otherClosestBaseLength)
        let otherLineMapLength = otherUnit.baseUnits().convert(otherClosestBaseLength, to: otherDisplayUnits)
        
        let displayFactor = scaleDisplay.lineMapLength / Double(scaleDisplay.lineDisplayLength)
        let convertedDisplayFactor = scaleDisplay.displayUnit.convert(displayFactor, to: otherDisplayUnits)
        let otherLineScreenLength = CGFloat(otherLineMapLength / convertedDisplayFactor)
        
        path.move(to: CGPoint(x: lineX + otherLineScreenLength, y: lineBottom))
        path.addLine(to: CGPoint(x: lineX + otherLineScreenLength, y: lineY))
        
        //
        // draw paths
        
        context.setLineCap(Scalebar.lineCap)
        context.setLineJoin(CGLineJoin.bevel)
        
        if let shadowColor = scalebar.shadowColor {
            var t = CGAffineTransform(translationX: shadowOffset.x, y: shadowOffset.y)
            if let shadowPath = path.copy(using: &t) {
                context.setLineWidth(lineWidth)
                context.setStrokeColor(shadowColor.cgColor)
                context.addPath(shadowPath)
                context.drawPath(using: .stroke)
            }
        }
        
        // draw path
        context.setLineWidth(lineWidth)
        context.setStrokeColor(scalebar.lineColor.cgColor)
        context.addPath(path)
        context.drawPath(using: .stroke)
        
        // draw top text
        
        let topUnitsText = " \(scaleDisplay.displayUnit.abbreviation)"
        let topUnitsTextWidth = topUnitsText.size(withAttributes: [.font: scalebar.font]).width
        
        let topText = "\(scaleDisplay.mapLengthString)\(topUnitsText)"
        let topTextWidth = topText.size(withAttributes: [.font: scalebar.font]).width
        let topTextMapLengthStringWidth = topTextWidth - topUnitsTextWidth
        
        let topTextFrame = CGRect(x: lineX + lineScreenLength + halfLineWidth - topTextMapLengthStringWidth,
                                  y: y,
                                  width: topTextWidth,
                                  height: scalebar.fontHeight)
        
        self.drawText(text: topText, frame: topTextFrame, alignment: .right)
        
        // draw bottom text
        if let numberString = Scalebar.numberFormatter.string(from: NSNumber(value: otherLineMapLength)) {
            let bottomUnitsText = " \(otherDisplayUnits.abbreviation)"
            let bottomUnitsTextWidth = bottomUnitsText.size(withAttributes: [.font: scalebar.font]).width
            
            let bottomText = "\(numberString)\(bottomUnitsText)"
            let bottomTextWidth = bottomText.size(withAttributes: [.font: scalebar.font]).width
            let bottomTextNumberStringWidth = bottomTextWidth - bottomUnitsTextWidth
            
            let bottomTextFrame = CGRect(x: lineX + otherLineScreenLength + halfLineWidth - bottomTextNumberStringWidth,
                                         y: lineY + Scalebar.tick2Height + Scalebar.labelYPad,
                                         width: bottomTextWidth,
                                         height: scalebar.fontHeight)
            
            self.drawText(text: bottomText, frame: bottomTextFrame, alignment: .right)
        }
        
        // reset the state
        context.restoreGState()
    }
}

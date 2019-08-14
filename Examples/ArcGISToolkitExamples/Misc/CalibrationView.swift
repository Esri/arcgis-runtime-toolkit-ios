//
//  CalibrationView.swift
//  ArcGISToolkitExamples
//
//  Created by Mark Dostal on 8/13/19.
//  Copyright © 2019 Esri. All rights reserved.
//

import UIKit
import ArcGIS

class CalibrationView: UIView, UIGestureRecognizerDelegate {
    
    public var cameraController: AGSTransformationMatrixCameraController!
    public var sceneView: AGSSceneView!

    private let calibrationDirectionsLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24.0)
        label.textColor = .darkText
        label.numberOfLines = 0
        label.text = "Calibration..."
        return label
    }()
    
    private let elevationSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = -100.0
        slider.maximumValue = 100.0
        
        // Rotate the slider so it slides up/down.
        slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)
        return slider
    }()
    
    private let headingSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = -180.0
        slider.maximumValue = 180.0
        return slider
    }()

    init(sceneView: AGSSceneView, cameraController: AGSTransformationMatrixCameraController) {
        super.init(frame: .zero)
        
        self.cameraController = cameraController
        self.sceneView = sceneView

        // Set a corner radius on the directions label
        calibrationDirectionsLabel.layer.cornerRadius = 8.0
        calibrationDirectionsLabel.layer.masksToBounds = true
        
        let labelView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        labelView.layer.cornerRadius = 8.0
        labelView.layer.masksToBounds = true

        labelView.contentView.addSubview(calibrationDirectionsLabel)
        calibrationDirectionsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            calibrationDirectionsLabel.leadingAnchor.constraint(equalTo: labelView.leadingAnchor, constant: 8),
            calibrationDirectionsLabel.trailingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: -8),
            calibrationDirectionsLabel.topAnchor.constraint(equalTo: labelView.topAnchor, constant: 8),
            calibrationDirectionsLabel.bottomAnchor.constraint(equalTo: labelView.bottomAnchor, constant: -8)
            ])
        
        addSubview(labelView)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelView.topAnchor.constraint(equalTo: topAnchor, constant: 88.0)
            ])
        
        addSubview(elevationSlider)
        elevationSlider.addTarget(self, action: #selector(elevationChanged(_:)), for: .valueChanged)
        elevationSlider.translatesAutoresizingMaskIntoConstraints = false
        let width: CGFloat = 500.0
        NSLayoutConstraint.activate([
//            elevationSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
//            elevationSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
//            elevationSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)

            
            
            
//            elevationSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
//            elevationSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -12),
            elevationSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
//            elevationSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -36),
            elevationSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: width),
            elevationSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: width / 2.0 - 36)
            
            
            
            
            
//            elevationSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 500.0)
//            elevationSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
//            elevationSlider.topAnchor.constraint(equalTo: topAnchor, constant: 36),
//            elevationSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -36),
//            elevationSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 500.0)
            ])
        
        addSubview(headingSlider)
        headingSlider.addTarget(self, action: #selector(headingChanged(_:)), for: .valueChanged)
        headingSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headingSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            headingSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            //            elevationSlider.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headingSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            return nil;
        } else {
            return hitView;
        }
    }

    var lastElevationValue: Float = 0
    @objc func elevationChanged(_ sender: UISlider){
        print("elevationChanged...")
        let camera = cameraController.originCamera
        cameraController.originCamera = camera.elevate(withDeltaAltitude: Double(sender.value - lastElevationValue))
        lastElevationValue = sender.value
    }
    
    var lastHeadingValue: Float = 0
    @objc func headingChanged(_ sender: UISlider){
        print("headingChanged...")
        let camera = cameraController.originCamera
        let newHeading = Float(camera.heading) + sender.value - lastHeadingValue
        cameraController.originCamera = camera.rotate(toHeading: Double(newHeading), pitch: camera.pitch, roll: camera.roll)
        lastHeadingValue = sender.value
    }

//    private var lastTouchPoint = CGPoint.zero
//
//    @objc func panGesture() {
//        guard let sceneView = sceneView, let cameraController = cameraController else { return }
//        switch panGR.state {
//        case .began:
//            lastTouchPoint = panGR.location(in: self)
//            break
//        case .changed:
//            let newTouchPoint = panGR.location(in: self)
//            let lastPoint = sceneView.screen(toBaseSurface: lastTouchPoint)
//            let newPoint = sceneView.screen(toBaseSurface: newTouchPoint)
//            let dx = newPoint.x - lastPoint.x
//            let dy = newPoint.y - lastPoint.y
//            print("dx = \(dx); dy = \(dy)")
//            let originCamera = cameraController.originCamera
//            cameraController.originCamera = AGSCamera(latitude: originCamera.location.y - dy,
//                                                      longitude: originCamera.location.x - dx,
//                                                      altitude: originCamera.location.z,
//                                                      heading: originCamera.heading,
//                                                      pitch: originCamera.pitch,
//                                                      roll: originCamera.roll)
//            lastTouchPoint = newTouchPoint
//            break
//        default:
//            break
//        }
//
//    }
    //    -(void)panGesture {
    //
    //    //
    //    // touchPt represents 1 of 2 possible point values
    //    //
    //    // If numTouches == 1: Then it's the actual point touched
    //    // If numTouches == 2: Then it's the center point of the two touches
    //
    //    CGPoint touchPt = CGPointZero;
    //
    //    NSInteger numTouches = [self.panGR numberOfTouches];
    //
    //    // "pinching" is YES until both fingers are let up,
    //    // which is good
    //    if (self.userPinching &&
    //    [self ags_anchoredOnLocationDisplay]){
    //    return;
    //    }
    //
    //    if (numTouches == 2) {
    //    _twoFingersDownAtOnePointDuringPanning = YES;
    //    //
    //    // make sure user wants 2 finger panning
    //    if (!_allowTwoFingerPanning) {
    //    // NOTE: even though we are not actually going to pan
    //    //      we need to update _lastPanTouchCount. In the case
    //    //      of a person panning with 1 finger, then adding a second, then
    //    //      letting up, we don't get a new recognizer event, this one just
    //    //      changes state..in StateChanged handling we update the last(Center|Touch)Loc
    //    //      when the user changes from 1 finger to 2, but ONLY if the touchCount is different.
    //    _lastPanTouchCount = numTouches;
    //    return;
    //    }
    //
    //    CGPoint t1 = [self.panGR locationOfTouch:0 inView:self];
    //    CGPoint t2 = [self.panGR locationOfTouch:1 inView:self];
    //    touchPt = CGPointMake((t1.x + t2.x) / 2, (t1.y + t2.y)/2);
    //    }
    //    else if (numTouches == 3){
    //    touchPt = [self.panGR locationOfTouch:0 inView:self];
    //    }
    //    else {
    //    touchPt = [self.panGR locationInView:self];
    //    }
    //
    //    if (_twoFingersDownAtOnePointDuringPanning &&
    //    [self ags_anchoredOnLocationDisplay]){
    //    if (self.panGR.state == UIGestureRecognizerStateEnded){
    //    _twoFingersDownAtOnePointDuringPanning = NO;
    //    }
    //    return;
    //    }
    //
    //    //
    //    // if our recognizer is just beginning, set our baseline
    //    // locations
    //    if (self.panGR.state == UIGestureRecognizerStateBegan) {
    //
    //    self.userDragging = YES;
    //
    //    if (numTouches == 1) {
    //    _lastTouchLoc = touchPt;
    //    [self setOrigin:touchPt];
    //    }
    //    else if (numTouches == 2) {
    //    _lastCenterLoc = touchPt;
    //    [self setOrigin:touchPt];
    //    }
    //    else if (numTouches == 3){
    //    _lastThreeFingerLoc = touchPt;
    //    // for pitch we use center
    //    [self setOrigin:self.center];
    //    }
    //    return;
    //    }
    //    //
    //    // fired when pan recognizer changes state:
    //    //      -either we panned, or changed from 1 to 2 touches, or vice versa
    //    //
    //    // We update our _last<x>Loc positions and update the _lastPanTouchCount
    //    else if (self.panGR.state == UIGestureRecognizerStateChanged) {
    //    if (numTouches != _lastPanTouchCount) {
    //
    //    if (numTouches == 1){
    //    _lastTouchLoc = touchPt;
    //    }
    //    else if (numTouches == 2) {
    //    _lastCenterLoc = touchPt;
    //    }
    //    else if (numTouches == 3){
    //    _lastThreeFingerLoc = touchPt;
    //    }
    //    _lastPanTouchCount = numTouches;
    //    }
    //
    //    float dx = 0.0;
    //    float dy = 0.0;
    //
    //
    //    if (numTouches == 1) {
    //    dx = touchPt.x - _lastTouchLoc.x;
    //    dy = touchPt.y - _lastTouchLoc.y;
    //    _lastTouchLoc = touchPt;
    //    }
    //    else if (numTouches == 2) {
    //    dx = touchPt.x - _lastCenterLoc.x;
    //    dy = touchPt.y - _lastCenterLoc.y;
    //    _lastCenterLoc = touchPt;
    //    }
    //    else if (numTouches == 3){
    //    dy = touchPt.y - _lastThreeFingerLoc.y;
    //    _lastThreeFingerLoc = touchPt;
    //    }
    //
    //    // panning for 1 touch, tilting for 2
    //    if (numTouches == 1){
    //    [self.rtcSceneView interactionUpdatePanOrigin:dx screenYDelta:dy error:nil];
    //    }
    //    else if (numTouches == 2){
    //    double pitch = (dy / self.frame.size.height) * -90.0;
    //    //NSLog(@"dy: %f", dy);
    //    [self.rtcSceneView interactionUpdateRotateAroundOrigin:0 pitchDeltaDegrees:pitch error:nil];
    //    }
    //    }
    //    else if (self.panGR.state == UIGestureRecognizerStateEnded) {
    //    //
    //    // If flick isn't allowed, return
    //    if (!self.interactionOptions.isFlickEnabled){
    //    self.userDragging = NO;
    //    return;
    //    }
    //    [self.rtcSceneView interactionActivateFlick:nil];
    //
    //    // needs to happen after animation gets kicked off
    //    self.userDragging = NO;
    //    }
    //    else if (self.panGR.state == UIGestureRecognizerStateCancelled) {
    //    self.userDragging = NO;
    //    }
    //    }

    //
    // when a pinch starts...get the resolution so we can use it
    // as the baseline for zoom
    @objc func pinchGesture() {
        
    }
//    - (void)pinchGesture {
//
//    if (self.pinchGR.state == UIGestureRecognizerStateBegan) {
//    self.userPinching = YES;
//    _lastPinchScale = 1.0;
//    [self setOrigin:[self.pinchGR locationInView:self]];
//    }
//    else if (self.pinchGR.state == UIGestureRecognizerStateChanged) {
//    double targetScale = self.pinchGR.scale / _lastPinchScale;
//    [self.rtcSceneView interactionUpdateZoomToOrigin:targetScale error:nil];
//    _lastPinchScale =  self.pinchGR.scale;
//    //NSLog(@"pinch scale; %f, %f", self.pinchGR.scale, targetScale);
//    }
//    else if (self.pinchGR.state == UIGestureRecognizerStateEnded ||
//    self.pinchGR.state == UIGestureRecognizerStateCancelled){
//    self.userPinching = NO;
//    }
//    }
    
    @objc func rotateGesture() {
        
    }
    
//    - (void)rotateGesture {
//
//    if (self.rotateGR.state == UIGestureRecognizerStateBegan) {
//    self.userRotating = YES;
//    CGPoint pt = [self.rotateGR locationInView:self];
//    [self setOrigin:pt];
//    }
//    else if (self.rotateGR.state == UIGestureRecognizerStateChanged) {
//    //
//    double angle = AGS_RAD2DEG(self.rotateGR.rotation);
//    [self.rtcSceneView interactionUpdateRotateAroundOrigin:angle pitchDeltaDegrees:0 error:nil];
//
//    //
//    // reset the rotation so we keep getting a delta's from the recognizer
//    self.rotateGR.rotation = 0.0f;
//    }
//    else if (self.rotateGR.state == UIGestureRecognizerStateEnded ||
//    self.rotateGR.state == UIGestureRecognizerStateCancelled) {
//    self.userRotating = NO;
//    }
//    }
//

}

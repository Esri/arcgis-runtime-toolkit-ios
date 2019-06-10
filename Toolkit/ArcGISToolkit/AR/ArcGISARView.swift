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
import ARKit
import ArcGIS

extension simd_quatd {
    init(statusBarOrientation: UIDeviceOrientation) {
        switch statusBarOrientation {
        case .landscapeLeft:
            self.init(ix: 0, iy: 0, iz: 0, r: 1)
        case .landscapeRight:
            self.init(ix: 0, iy: 0, iz: 1, r: 0)
        case .portrait:
            let squareRootOfOneHalf = (0.5 as Double).squareRoot()
            self.init(ix: 0, iy: 0, iz: squareRootOfOneHalf, r: squareRootOfOneHalf)
        case .portraitUpsideDown:
            let squareRootOfOneHalf = (0.5 as Double).squareRoot()
            self.init(ix: 0, iy: 0, iz: -squareRootOfOneHalf, r: squareRootOfOneHalf)
        default:
            // default to landscapeLeft
            self.init(ix: 0, iy: 0, iz: 0, r: 1)
        }
    }
}

extension ArcGISARView.clError: CustomNSError {
    static var errorDomain: String {
        return kCLErrorDomain
    }

    var errorCode: Int {
        switch self {
        case .accessDenied:
            return CLError.Code.denied.rawValue
        case .missingPListKey:
            return CLError.Code.denied.rawValue
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to the device location is denied."
        case .missingPListKey:
            return "You must specify a location usage description key (NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription) in your plist."
        }
    }
}

public class ArcGISARView: UIView {
    
    enum clError {
        case accessDenied
        case missingPListKey
    }

    // MARK: public properties
    
    /// The view used to display the `ARKit` camera image and 3D `SceneKit` content.
    public lazy private(set) var arSCNView = ARSCNView(frame: .zero)
    
    /// The view used to display ArcGIS 3D content.
    public lazy private(set) var sceneView = AGSSceneView(frame: .zero)
    
    /// The world tracking information used by `ARKit`.
    public var arConfiguration: ARConfiguration = {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        return config
        }() {
        didSet {
            // Start tracking using the new configuration.
            startTracking()
        }
    }

    /// The viewpoint camera used to set the initial view of the sceneView instead of the devices GPS location via the locationManager.
    public var originCamera: AGSCamera?
    
    /// The translation factor used to support a table top AR experience.
    public var translationTransformationFactor: Double = 1.0
    
    // We implement ARSCNViewDelegate methods, but will use `arSCNViewDelegate` to forward them to clients.
    weak open var arSCNViewDelegate: ARSCNViewDelegate?

    // MARK: private properties
    
    /// Whether to display the camera image or not.
    private var renderVideoFeed = true
    
    /// Used to determine the device location when originCamera is not set.
    private lazy var locationManager: CLLocationManager = { [unowned self] in
        let lm = CLLocationManager()
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.delegate = self
        return lm
    }()
    
    /// Initial location from locationManager.
    private var initialLocation: CLLocation?
    
    /// Current horizontal accuracy of the device.
    private var horizontalAccuracy: CLLocationAccuracy = .greatestFiniteMagnitude
    
    /// The intial camera position and orientation whether it was set via originCamera or the locationManager.
    private var initialTransformationMatrix = AGSTransformationMatrix()
    
    /// Whether `ARKit` is supported on this device.
    private var isSupported = {
        return ARWorldTrackingConfiguration.isSupported
    }()
    
    /// Whether the client has been notfiied of start/failure.
    private var notifiedStartOrFailure = false
    
    /// Used when calculating framerate.
    private var lastUpdateTime: TimeInterval = 0
    
    // A quaternion used to compensate for the pitch beeing 90 degrees on `ARKit`; used to calculate the current device transformation for each frame.
    let compensationQuat:simd_quatd = simd_quatd(ix: (sin(45 / (180 / .pi))), iy: 0, iz: 0, r: (cos(45 / (180 / .pi))))
    
    /// The quaternion used to represent the device orientation; used to calculate the current device transformation for each frame; defaults to landcape-left.
    var orientationQuat:simd_quatd = simd_quatd(statusBarOrientation: .landscapeLeft)
    
    // MARK: Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInitialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    /// Initializer used to denote whether to display the live camera image.
    ///
    /// - Parameter renderVideoFeed: Whether to display the live camera image.
    public convenience init(renderVideoFeed: Bool){
        self.init(frame: .zero)
        self.renderVideoFeed = renderVideoFeed
    }
    
    deinit {
        stopTracking()
    }
    
    /// Initialization code shared between all initializers.
    private func sharedInitialization(){
        // Add the ARSCNView to our view.
        addSubviewWithConstraints(arSCNView)
        arSCNView.delegate = self
        
        // Add sceneView to view and setup constraints.
        addSubviewWithConstraints(sceneView)

        // Make our sceneView's background transparent, no atmosphereEffect.
        sceneView.isBackgroundTransparent = true
        sceneView.atmosphereEffect = .none
        
        // Tell the sceneView we will be calling `renderFrame()` manually.
        sceneView.isManualRendering = true
        
        // We haven't yet notified user of start or failure.
        notifiedStartOrFailure = false
        
        // Set intitial orientationQuat.
        orientationChanged(notification: nil)
    }
    
    // MARK: Public
    
    /// Determines the map point for the given screen point.
    ///
    /// - Parameter toLocation: The point in screen coordinates.
    /// - Returns: The map point corresponding to screenPoint.
    public func arScreenToLocation(screenPoint: AGSPoint) -> AGSPoint {
        fatalError("arScreen(toLocation:) has not been implemented")
    }
    
    /// Resets the device tracking, using `originCamera` if it's not nil or the device's GPS location via the locationManager.
    public func resetTracking() {
        initialLocation = nil
        startTracking()
    }

    /// Resets the device tracking, using the device's GPS location via the locationManager.
    ///
    /// - Returns: Reset operation success or failure.
    public func resetUsingLocationServices() -> Bool {
        fatalError("resetUsingLocationServices() has not been implemented")
    }
    
    /// Resets the device tracking using a spacial anchor.
    ///
    /// - Returns: Reset operation success or failure.
    public func resetUsingSpatialAnchor() -> Bool {
        fatalError("resetUsingSpatialAnchor() has not been implemented")
    }
    
    /// Starts device tracking.
    public func startTracking() {
        if !isSupported {
            didStartOrFailWithError(ARError(.unsupportedConfiguration))
            return
        }
        
        if let origin = originCamera {
            // We have a starting camera.
            initialTransformationMatrix = origin.transformationMatrix
            sceneView.setViewpointCamera(origin)
            finalizeStart()
        }
        else {
            // No starting camera, use location manger to get initial location.
            let authStatus = CLLocationManager.authorizationStatus()
            switch authStatus {
            case .notDetermined:
                startWithAccessNotDetermined()
            case .restricted, .denied:
                startWithAccessDenied()
            case .authorizedAlways, .authorizedWhenInUse:
                startWithAccessAuthorized()
            }
        }
        
        //TODO:  reloook at the mechanism by which we're getting notified of orientation changed events...
        // We need to know when the device orientation changes in order to update the Camera transformation.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.orientationChanged(notification:)),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    /// Suspends device tracking.
    public func stopTracking() {
        arSCNView.session.pause()
        stopUpdatingLocationAndHeading()
        
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Private
    
    /// Operations that happen after device tracking has started.
    fileprivate func finalizeStart() {
        // Hide the camera image if necessary.
        arSCNView.isHidden = !renderVideoFeed
        
        // Run the ARSession.
        arSCNView.session.run(arConfiguration, options:.resetTracking)
        didStartOrFailWithError(nil)
    }

    /// Adds subView to superView with appropriate constraints.
    ///
    /// - Parameter subview: The subView to add.
    fileprivate func addSubviewWithConstraints(_ subview: UIView) {
        // Add subview to view and setup constraints.
        addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            subview.topAnchor.constraint(equalTo: self.topAnchor),
            subview.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
    }
    
    /// Start the locationManager with undetermined access.
    fileprivate func startWithAccessNotDetermined() {
        if (Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil) {
            locationManager.requestWhenInUseAuthorization()
        }
        if (Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil) {
            locationManager.requestAlwaysAuthorization()
        }
        else{
            didStartOrFailWithError(ArcGISARView.clError.missingPListKey)
        }
    }
    
    /// Start updating the location and heading via the locationManager.
    fileprivate func startUpdatingLocationAndHeading() {
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    /// Stop updating location and heading.
    fileprivate func stopUpdatingLocationAndHeading() {
        locationManager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.stopUpdatingHeading()
        }
    }

    /// Start the locationManager with denied access.
    fileprivate func startWithAccessDenied() {
        didStartOrFailWithError(ArcGISARView.clError.accessDenied)
    }
    
    /// Start the locationManager with authorized access.
    fileprivate func startWithAccessAuthorized() {
        startUpdatingLocationAndHeading()
    }
    
    /// Potential notification to the user of an error starting device tracking.
    ///
    /// - Parameter error: The error that occurred when starting tracking.
    fileprivate func didStartOrFailWithError(_ error: Error?) {
        if !notifiedStartOrFailure, let error = error {
            // TODO: present error to user...
            print("didStartOrFailWithError: \(String(reflecting:error))")
        }
        
        notifiedStartOrFailure = true
    }
    
    /// Handle a change in authorization status to "denied".
    fileprivate func handleAuthStatusChangedAccessDenied() {
        // auth status changed to denied
        stopUpdatingLocationAndHeading()
        
        // We were waiting for user prompt to come back, so notify.
        didStartOrFailWithError(ArcGISARView.clError.accessDenied)
    }
    
    /// Handle a change in authorization status to "authorized".
    fileprivate func handleAuthStatusChangedAccessAuthorized() {
        // Auth status changed to authorized; now that we have authorization - start updating location and heading.
        didStartOrFailWithError(nil)
        startUpdatingLocationAndHeading()
    }
    
    /// Called when device orientation changes.
    ///
    /// - Parameter notification: The notification.
    @objc func orientationChanged(notification: Notification?) {
        // Handle rotation here.
        orientationQuat = simd_quatd(statusBarOrientation: UIDevice.current.orientation)
    }
}

// MARK: - ARSCNViewDelegate
extension ArcGISARView: ARSCNViewDelegate {
    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        return arSCNViewDelegate?.renderer?(renderer, nodeFor: anchor)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        arSCNViewDelegate?.renderer?(renderer, didAdd: node, for: anchor)
    }

    public func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        arSCNViewDelegate?.renderer?(renderer, willUpdate: node, for: anchor)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        arSCNViewDelegate?.renderer?(renderer, didUpdate: node, for: anchor)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        arSCNViewDelegate?.renderer?(renderer, didRemove: node, for: anchor)
    }
}

// MARK: - ARSessionObserver (via ARSCNViewDelegate)
extension ArcGISARView: ARSessionObserver {
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        arSCNViewDelegate?.session?(session, didFailWithError: error)
    }
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        arSCNViewDelegate?.session?(session, cameraDidChangeTrackingState: camera)
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        arSCNViewDelegate?.sessionWasInterrupted?(session)
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        arSCNViewDelegate?.sessionWasInterrupted?(session)
    }
    
    @available(iOS 11.3, *)
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return arSCNViewDelegate?.sessionShouldAttemptRelocalization?(session) ?? false
    }
    
    public func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        arSCNViewDelegate?.session?(session, didOutputAudioSampleBuffer: audioSampleBuffer)
    }
}

// MARK: - SCNSceneRendererDelegate (via ARSCNViewDelegate)
extension ArcGISARView: SCNSceneRendererDelegate {

    public  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        arSCNViewDelegate?.renderer?(renderer, updateAtTime: time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        arSCNViewDelegate?.renderer?(renderer, didApplyConstraintsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        arSCNViewDelegate?.renderer?(renderer, didSimulatePhysicsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {
        arSCNViewDelegate?.renderer?(renderer, didApplyConstraintsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        // Get transform from SCNView.pointOfView.
        guard let transform = arSCNView.pointOfView?.transform else { return }
        let cameraTransform = simd_double4x4(transform)
        
        let finalQuat:simd_quatd = simd_mul(simd_mul(compensationQuat, simd_quatd(cameraTransform)), orientationQuat)
        var transformationMatrix = AGSTransformationMatrix(quaternionX: finalQuat.vector.x,
                                                           quaternionY: finalQuat.vector.y,
                                                           quaternionZ: finalQuat.vector.z,
                                                           quaternionW: finalQuat.vector.w,
                                                           translationX: (cameraTransform.columns.3.x) * translationTransformationFactor,
                                                           translationY: (-cameraTransform.columns.3.z) * translationTransformationFactor,
                                                           translationZ: (cameraTransform.columns.3.y) * translationTransformationFactor)
        
        transformationMatrix = initialTransformationMatrix.addTransformation(transformationMatrix)
        
        let camera = AGSCamera(transformationMatrix: transformationMatrix)
        sceneView.setViewpointCamera(camera)
        
        sceneView.renderFrame()

        // Calculate frame rate.
        let frametime = time - lastUpdateTime
        print("Frame rate = \(String(reflecting: Int((1.0 / frametime).rounded())))")
        lastUpdateTime = time
        
        // Call our arSCNViewDelegate method.
        arSCNViewDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        arSCNViewDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}

// MARK: - CLLocationManagerDelegate
extension ArcGISARView: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0.0 else { return }
        
        if initialLocation == nil {
            initialLocation = location
            horizontalAccuracy = location.horizontalAccuracy
            
            let locationPoint = AGSPoint(x: location.coordinate.longitude,
                                         y: location.coordinate.latitude,
                                         z: location.altitude,
                                         spatialReference: .wgs84())
            let camera = AGSCamera(location: locationPoint, heading: 0.0, pitch: 0.0, roll: 0.0)
            initialTransformationMatrix = camera.transformationMatrix
            sceneView.setViewpointCamera(camera)
            
            finalizeStart()
        }
        else if location.horizontalAccuracy < horizontalAccuracy {
            horizontalAccuracy = location.horizontalAccuracy
        }
        
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        didStartOrFailWithError(error)
    }
    
    public  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let authStatus = CLLocationManager.authorizationStatus()
        switch authStatus {
        case .notDetermined:
            break
        case .restricted, .denied:
            handleAuthStatusChangedAccessDenied()
        case .authorizedAlways, .authorizedWhenInUse:
            handleAuthStatusChangedAccessAuthorized()
        }
    }
}

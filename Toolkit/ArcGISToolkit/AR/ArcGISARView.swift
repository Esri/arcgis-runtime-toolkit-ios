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

public class ArcGISARView: UIView {
    
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
    
    // We implement ARSessionDelegate methods, but will use `sessionDelegate` to forward them to clients.
    weak open var sessionDelegate: ARSessionDelegate?
    
    // We implement SCNSceneRendererDelegate methods, but will use `scnSceneRendererDelegate` to forward them to clients.
    weak open var scnSceneRendererDelegate: SCNSceneRendererDelegate?

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
    private var isSupported = false
    
    /// Whether the client has been notfiied of start/failure.
    private var notifiedStartOrFailure = false
    
    /// Used when calculating framerate.
    private var lastUpdateTime: TimeInterval = 0
    
    // A quaternion used to compensate for the pitch beeing 90 degrees on `ARKit`; used to calculate the current device transformation for each frame.
    let compensationQuat:simd_quatd = simd_quaternion((sin(45 / (180 / .pi))), 0, 0, (cos(45 / (180 / .pi))))
    
    /// The quaternion used to represent the device orientation; used to calculate the current device transformation for each frame; defaults to landcape-left.
    var orientationQuat:simd_quatd = simd_quaternion(0, 0, 1, 0)
    
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
    
    /// Initialization code shared between all initializers.
    private func sharedInitialization(){
        // `ARKit` initialization.
        isSupported = ARWorldTrackingConfiguration.isSupported
        
        addSubviewWithConstraints(arSCNView)
        arSCNView.session.delegate = self
        (arSCNView as SCNSceneRenderer).delegate = self
        
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
    /// - Parameter screenPoint: The point in screen coordinates.
    /// - Returns: The map point corresponding to screenPoint.
    public func arScreenToLocation(screenPoint: AGSPoint) -> AGSPoint {
        return AGSPoint(x: 0.0, y: 0.0, spatialReference: nil)
    }
    
    /// Resets the device tracking, using originCamera if it's not nil or the device's GPS location via the locationManager.
    public func resetTracking() {
        initialLocation = nil
        startTracking()
    }

    /// Resets the device tracking, using the device's GPS location via the locationManager.
    ///
    /// - Returns: Reset operation success or failure.
    public func resetUsingLocationServices() -> Bool {
        return false
    }
    
    /// Resets the device tracking using a spacial anchor.
    ///
    /// - Returns: Reset operation success or failure.
    public func resetUsingSpatialAnchor() -> Bool {
        return false
    }
    
    /// Starts device tracking.
    public func startTracking() {
        if !isSupported {
            didStartOrFailWithError(ArcGISARView.notSupportedError())
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
            didStartOrFailWithError(ArcGISARView.missingPListKeyError())
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
        didStartOrFailWithError(ArcGISARView.accessDeniedError())
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
        didStartOrFailWithError(ArcGISARView.accessDeniedError())
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
        switch UIApplication.shared.statusBarOrientation {
        case .landscapeLeft:
            orientationQuat = simd_quaternion(0, 0, 1.0, 0)
        case .landscapeRight:
            orientationQuat = simd_quaternion(0, 0, 0, 1.0)
        case .portrait:
            orientationQuat = simd_quaternion(0, 0, sqrt(0.5), sqrt(0.5))
        case .portraitUpsideDown:
            orientationQuat = simd_quaternion(0, 0, -sqrt(0.5), sqrt(0.5))
        default:
            break
        }
    }
    
    // MARK: Errors
    
    /// Error used when `ARKit` is not supported on the current device.
    ///
    /// - Returns: Error stating `ARKit` not supported.
    fileprivate class func notSupportedError() -> NSError {
        let userInfo = [NSLocalizedDescriptionKey : "The device does not support ARKit functionality."]
        return NSError(domain: ARErrorDomain, code: ARError.unsupportedConfiguration.rawValue, userInfo: userInfo)
    }
    
    /// Error used when access to the device location is denied.
    ///
    /// - Returns: Error stating access to location information is denied.
    fileprivate class func accessDeniedError() -> NSError{
        let userInfo = [NSLocalizedDescriptionKey : "Access to the device location is denied."]
        return NSError(domain: kCLErrorDomain, code: CLError.Code.denied.rawValue, userInfo: userInfo)
    }
    
    /// Error used when required plist information is missing.
    ///
    /// - Returns: Error stating plist information is missing.
    fileprivate class func missingPListKeyError() -> NSError{
        let userInfo = [NSLocalizedDescriptionKey : "You must specify a location usage description key (NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription) in your plist."]
        return NSError(domain: kCLErrorDomain, code: CLError.Code.denied.rawValue, userInfo: userInfo)
    }
}

// MARK: - ARSessionDelegate

extension ArcGISARView: ARSessionDelegate {
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        sessionDelegate?.session?(session, didUpdate: frame)
    }

    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        sessionDelegate?.session?(session, didAdd: anchors)
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        sessionDelegate?.session?(session, didUpdate: anchors)
    }
    
    public func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        sessionDelegate?.session?(session, didRemove: anchors)
    }
}

// MARK: - ARSessionObserver
extension ArcGISARView: ARSessionObserver {
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert describing the error.
            let alertController = UIAlertController(title: "Could not start tracking.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Tracking", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.startTracking()
            }
            alertController.addAction(restartAction)
            
            guard let rootController = UIApplication.shared.keyWindow?.rootViewController else { return }
            rootController.present(alertController, animated: true, completion: nil)
        }
        
        sessionDelegate?.session?(session, didFailWithError: error)
    }
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        sessionDelegate?.session?(session, cameraDidChangeTrackingState: camera)
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        sessionDelegate?.sessionWasInterrupted?(session)
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        sessionDelegate?.sessionWasInterrupted?(session)
    }
    
    @available(iOS 11.3, *)
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        if let result = sessionDelegate?.sessionShouldAttemptRelocalization?(session) {
            return result
        }
        return false
    }
    
    public func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        sessionDelegate?.session?(session, didOutputAudioSampleBuffer: audioSampleBuffer)
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

// MARK: - SCNSceneRendererDelegate
extension ArcGISARView: SCNSceneRendererDelegate {

    public  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        scnSceneRendererDelegate?.renderer?(renderer, updateAtTime: time)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        scnSceneRendererDelegate?.renderer?(renderer, didApplyConstraintsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        scnSceneRendererDelegate?.renderer?(renderer, didSimulatePhysicsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {
        scnSceneRendererDelegate?.renderer?(renderer, didApplyConstraintsAtTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        // Get transform from SCNView.pointOfView.
        guard let transform = arSCNView.pointOfView?.transform else { return }
        let cameraTransform = simd_double4x4(transform)
        
        let finalQuat:simd_quatd = simd_mul(simd_mul(compensationQuat, simd_quaternion(cameraTransform)), orientationQuat)
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
        
        //
        // Call our scnSceneRendererDelegate.
        //
        scnSceneRendererDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        scnSceneRendererDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}

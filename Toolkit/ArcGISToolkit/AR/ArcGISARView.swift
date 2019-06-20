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

extension AGSDeviceOrientation {
    init?(statusBarOrientation: UIDeviceOrientation) {
        switch statusBarOrientation {
        case .landscapeLeft:
            self.init(rawValue: AGSDeviceOrientation.landscapeRight.rawValue)
        case .landscapeRight:
            self.init(rawValue: AGSDeviceOrientation.landscapeLeft.rawValue)
        case .portrait:
            self.init(rawValue: AGSDeviceOrientation.portrait.rawValue)
        case .portraitUpsideDown:
            self.init(rawValue: AGSDeviceOrientation.reversePortrait.rawValue)
        default:
            // default to landscapeLeft
            self.init(rawValue: AGSDeviceOrientation.landscapeLeft.rawValue)
        }
    }
}

extension ArcGISARView.CoreLocationError: CustomNSError {
    static var errorDomain: String {
        return kCLErrorDomain
    }

    var errorCode: Int {
        return CLError.Code.denied.rawValue
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
    
    enum CoreLocationError: Swift.Error {
        case accessDenied
        case missingPListKey
    }

    // MARK: public properties
    
    /// The view used to display the `ARKit` camera image and 3D `SceneKit` content.
    public let arSCNView = ARSCNView(frame: .zero)
    
    /// The view used to display ArcGIS 3D content.
    public let sceneView = AGSSceneView(frame: .zero)
    
    /// The camera controller used to control the Scene
    private let cameraController = AGSTransformationMatrixCameraController()
    
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
    public var originCamera: AGSCamera? {
        didSet {
            guard let newCamera = originCamera else { return }
            // Set the camera as the originCamera on the cameraController and reset tracking.
            cameraController.originCamera = newCamera
            resetTracking()
        }
    }
    
    /// The translation factor used to support a table top AR experience.
    public var translationTransformationFactor: Double = 1.0
    
    /// We implement `ARSCNViewDelegate` methods, but will use `arSCNViewDelegate` to forward them to clients.
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
    
    /// Whether `ARKit` is supported on this device.
    private var isSupported = {
        return ARWorldTrackingConfiguration.isSupported
    }()
    
    /// Whether the client has been notfiied of start/failure.
    private var notifiedStartOrFailure = false
    
    /// Used when calculating framerate.
    private var lastUpdateTime: TimeInterval = 0
    
    /// A quaternion used to compensate for the pitch being 90 degrees on `ARKit`; used to calculate the current device transformation for each frame.
    private let compensationQuat: simd_quatd = simd_quatd(ix: (sin(45 / (180 / .pi))), iy: 0, iz: 0, r: (cos(45 / (180 / .pi))))
    
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

        // Make our sceneView's space effect be transparent, no atmosphereEffect.
        sceneView.spaceEffect = .transparent
        sceneView.atmosphereEffect = .none
        
        sceneView.cameraController = cameraController
        
        // Tell the sceneView we will be calling `renderFrame()` manually.
        sceneView.isManualRendering = true
        
        // We haven't yet notified user of start or failure.
        notifiedStartOrFailure = false
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
        
        if originCamera != nil {
            // We have a starting camera, so no need to start the location manager, just finalizeStart().
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
    }

    /// Suspends device tracking.
    public func stopTracking() {
        arSCNView.session.pause()
        stopUpdatingLocationAndHeading()
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
            didStartOrFailWithError(CoreLocationError.missingPListKey)
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
        didStartOrFailWithError(CoreLocationError.accessDenied)
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
        }
        
        notifiedStartOrFailure = true
    }
    
    /// Handle a change in authorization status to "denied".
    fileprivate func handleAuthStatusChangedAccessDenied() {
        // auth status changed to denied
        stopUpdatingLocationAndHeading()
        
        // We were waiting for user prompt to come back, so notify.
        didStartOrFailWithError(CoreLocationError.accessDenied)
    }
    
    /// Handle a change in authorization status to "authorized".
    fileprivate func handleAuthStatusChangedAccessAuthorized() {
        // Auth status changed to authorized; now that we have authorization - start updating location and heading.
        didStartOrFailWithError(nil)
        startUpdatingLocationAndHeading()
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
        // If we haven't started yet, return.
        guard notifiedStartOrFailure else { return }
        
        // Get transform from SCNView.pointOfView.
        guard let transform = arSCNView.pointOfView?.transform else { return }
        let cameraTransform = simd_double4x4(transform)
        
        // Calculate our final quaternion and create the new transformation matrix.
        let finalQuat:simd_quatd = simd_mul(compensationQuat, simd_quatd(cameraTransform))
        let transformationMatrix = AGSTransformationMatrix(quaternionX: finalQuat.vector.x,
                                                           quaternionY: finalQuat.vector.y,
                                                           quaternionZ: finalQuat.vector.z,
                                                           quaternionW: finalQuat.vector.w,
                                                           translationX: (cameraTransform.columns.3.x) * translationTransformationFactor,
                                                           translationY: (-cameraTransform.columns.3.z) * translationTransformationFactor,
                                                           translationZ: (cameraTransform.columns.3.y) * translationTransformationFactor)
        
        // Set the matrix on the camera controller.
        cameraController.transformationMatrix = transformationMatrix
        
        // Set FOV on camera.
        if let camera = arSCNView.session.currentFrame?.camera {
            let intrinsics = camera.intrinsics
            let imageResolution = camera.imageResolution
            sceneView.setFieldOfViewFromLensIntrinsicsWithXFocalLength(intrinsics[0][0],
                                                                       yFocalLength: intrinsics[1][1],
                                                                       xPrincipal: intrinsics[2][0],
                                                                       yPrincipal: intrinsics[2][1],
                                                                       xImageSize: Float(imageResolution.width),
                                                                       yImageSize: Float(imageResolution.height),
                                                                       deviceOrientation: AGSDeviceOrientation.init(statusBarOrientation: UIDevice.current.orientation) ?? .landscapeRight)
        }
        //        print("FOV: \(sceneView.fieldOfView); distortion = \(sceneView.fieldOfViewDistortionRatio)")

        // Render the Scene with the new transformation.
        sceneView.renderFrame()

        // Calculate frame rate.
//        let frametime = time - lastUpdateTime
//        print("Frame rate = \(String(reflecting: Int((1.0 / frametime).rounded())))")
//        lastUpdateTime = time
        
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
            
            // Create a new camera based on our location and set it on the cameraController.
            cameraController.originCamera = AGSCamera(location: locationPoint, heading: 0.0, pitch: 0.0, roll: 0.0)
            finalizeStart()
        }
        else if location.horizontalAccuracy < horizontalAccuracy {
            horizontalAccuracy = location.horizontalAccuracy
        }
        
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        didStartOrFailWithError(error)
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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

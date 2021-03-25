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

/// Controls how the locations generated from the location data source are used during AR tracking.
///
/// - ignore: Ignore all location data source locations.
/// - initial: Use only the initial location from the location data source and ignore all subsequent locations.
/// - continuous: Use all locations from the location data source.
public enum ARLocationTrackingMode {
    case ignore
    case initial
    case continuous
}

public class ArcGISARView: UIView {
    // MARK: public properties
    
    /// The view used to display the `ARKit` camera image and 3D `SceneKit` content.
    /// - Since: 100.6.0
    public let arSCNView = ARSCNView(frame: .zero)
    
    /// The initial transformation used for a table top experience.  Defaults to the Identity Matrix.
    /// - Since: 100.6.0
    public var initialTransformation: AGSTransformationMatrix = .identity
    
    /// Denotes whether tracking location and angles has started.
    /// - Since: 100.6.0
    public private(set) var isTracking: Bool = false
    
    /// Denotes whether ARKit is being used to track location and angles.
    /// - Since: 100.6.0
    public private(set) var isUsingARKit: Bool = true

    /// The data source used to get device location.  Used either in conjuction with ARKit data or when ARKit is not present or not being used.
    /// - Since: 100.6.0
    public var locationDataSource: AGSLocationDataSource? {
        didSet {
            locationDataSource?.locationChangeHandlerDelegate = self
        }
    }

    /// The viewpoint camera used to set the initial view of the sceneView instead of the device's GPS location via the location data source.  You can use Key-Value Observing to track changes to the origin camera.
    /// - Since: 100.6.0
    @objc public dynamic var originCamera: AGSCamera {
        get {
            return cameraController.originCamera
        }
        set {
            cameraController.originCamera = newValue
        }
    }
    
    /// Determines the clipping distance around the originCamera. The units are meters; the default is 0.0. When the value is set to 0.0 there is no enforced clipping distance.
    /// Setting the value to 10.0 will only render data 10 meters around the originCamera.
    /// - Since: 100.7.0
    public var clippingDistance: Double {
        get {
            return cameraController.clippingDistance
        }
        set {
            cameraController.clippingDistance = newValue
        }
    }
    
    /// The view used to display ArcGIS 3D content.
    /// - Since: 100.6.0
    public let sceneView = AGSSceneView(frame: .zero)
    
    /// The translation factor used to support a table top AR experience.
    /// - Since: 100.6.0
    @objc public dynamic var translationFactor: Double {
        get {
            return cameraController.translationFactor
        }
        set {
            cameraController.translationFactor = newValue
        }
    }
    
    /// The world tracking information used by `ARKit`.
    /// - Since: 100.6.0
    public var arConfiguration: ARConfiguration = {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.planeDetection = [.horizontal]
        return config
        }() {
        didSet {
            // If we're already tracking, reset tracking to use the new configuration.
            if isTracking, isUsingARKit {
                arSCNView.session.run(arConfiguration, options: .resetTracking)
            }
        }
    }

    /// We implement `ARSCNViewDelegate` methods, but will use `arSCNViewDelegate` to forward them to clients.
    /// - Since: 100.6.0
    public weak var arSCNViewDelegate: ARSCNViewDelegate?

    /// We implement `AGSLocationChangeHandlerDelegate` methods, but will use `locationChangeHandlerDelegate` to forward them to clients.
    /// - Since: 100.6.0
    public weak var locationChangeHandlerDelegate: AGSLocationChangeHandlerDelegate?

    // MARK: Private properties
        
    /// The `AGSTransformationMatrixCameraController` used to control the Scene.
    @objc private let cameraController = AGSTransformationMatrixCameraController()
    
    /// Whether `ARKit` is supported on this device.
    private let deviceSupportsARKit: Bool = {
        return ARWorldTrackingConfiguration.isSupported
    }()

    /// Denotes whether we've received our initial location from the data source.
    private var didSetInitialLocation: Bool = false

    /// The last portrait or landscape orientation value.
    private var lastGoodDeviceOrientation = UIDeviceOrientation.portrait
    
    /// The tracking mode controlling how the locations generated from the location data source are used during AR tracking.
    private var locationTrackingMode: ARLocationTrackingMode = .ignore

    // MARK: Initializers
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        sharedInitialization()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    /// Initializer used to denote whether to display the live camera image.
    ///
    /// - Parameters:
    ///   - renderVideoFeed: Whether to display the live camera image.
    /// - Since: 100.6.0
    public convenience init(renderVideoFeed: Bool) {
        self.init(frame: .zero)
        
        if !isUsingARKit || !renderVideoFeed {
            // User is not using ARKit, or they don't want to see video,
            // set the arSCNView.alpha to 0.0 so it doesn't display.
            arSCNView.alpha = 0.0
        }
        
        // Tell the sceneView we will be calling `renderFrame()` manually if we're using ARKit.
        // This overrides the `sharedInitialization()` `isManualRendering` code
        sceneView.isManualRendering = isUsingARKit
    }
    
    deinit {
        stopTracking()
    }
    
    /// Initialization code shared between all initializers.
    private func sharedInitialization() {
        // Add the ARSCNView to our view.
        if deviceSupportsARKit {
            addSubviewWithConstraints(arSCNView)
            arSCNView.delegate = self
        }

        // Always use ARKit if device supports it.
        isUsingARKit = deviceSupportsARKit

        // Add sceneView to view and setup constraints.
        addSubviewWithConstraints(sceneView)

        // Make our sceneView's spaceEffect be transparent, no atmosphereEffect.
        sceneView.spaceEffect = .transparent
        sceneView.atmosphereEffect = .none
        
        // Set the camera controller on the sceneView
        sceneView.cameraController = cameraController
        
        // Tell the sceneView we will be calling `renderFrame()` manually if we're using ARKit.
        sceneView.isManualRendering = isUsingARKit
    }
    
    /// Implementing this method will allow the computed `translationFactor` property to generate KVO events when the `cameraController.translationFactor` value changes.
    ///
    /// - Parameter key: The key we want to observe.
    /// - Returns: A set of key paths for properties whose values affect the value of the specified key.
    override public class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        var set = super.keyPathsForValuesAffectingValue(forKey: key)
        if key == #keyPath(translationFactor) {
            set.insert(#keyPath(cameraController.translationFactor))
        } else if key == #keyPath(originCamera) {
            set.insert(#keyPath(cameraController.originCamera))
        }

        return set
    }

    // MARK: Public
    
    /// Determines the map point for the given screen point.
    ///
    /// - Parameter screenPoint: The point in screen coordinates.
    /// - Returns: The map point corresponding to screenPoint.
    /// - Since: 100.6.0
    public func arScreenToLocation(screenPoint: CGPoint) -> AGSPoint? {
        // Use the `internalHitTest` method to get the matrix of `screenPoint`.
        guard let localOffsetMatrix = internalHitTest(screenPoint: screenPoint) else { return nil }
        
        let currOriginMatrix = originCamera.transformationMatrix

        // Scale translation by translationFactor.
        let translatedMatrix = AGSTransformationMatrix(quaternionX: localOffsetMatrix.quaternionX,
                                                       quaternionY: localOffsetMatrix.quaternionY,
                                                       quaternionZ: localOffsetMatrix.quaternionZ,
                                                       quaternionW: localOffsetMatrix.quaternionW,
                                                       translationX: localOffsetMatrix.translationX * translationFactor,
                                                       translationY: localOffsetMatrix.translationY * translationFactor,
                                                       translationZ: localOffsetMatrix.translationZ * translationFactor)
        let mapPointMatrix = currOriginMatrix.addTransformation(translatedMatrix)
        
        // Create a camera from transformationMatrix and return its location.
        return AGSCamera(transformationMatrix: mapPointMatrix).location
    }

    /// Resets the device tracking and related properties.
    /// - Since: 100.6.0
    public func resetTracking() {
        didSetInitialLocation = false
        initialTransformation = .identity
        if isUsingARKit {
            arSCNView.session.run(arConfiguration, options: [.resetTracking, .removeExistingAnchors])
        }
        
        cameraController.transformationMatrix = .identity
    }
    
    /// Sets the initial transformation used to offset the originCamera.  The initial transformation is based on an AR point determined via existing plane hit detection from `screenPoint`.  If an AR point cannot be determined, this method will return `false`.
    ///
    /// - Parameter screenPoint: The screen point to determine the `initialTransformation` from.
    /// - Returns: Whether setting the `initialTransformation` succeeded or failed.
    /// - Since: 100.6.0
    public func setInitialTransformation(using screenPoint: CGPoint) -> Bool {
        // Use the `internalHitTest` method to get the matrix of `screenPoint`.
        guard let matrix = internalHitTest(screenPoint: screenPoint) else { return false }
        
        // Set the `initialTransformation` as the AGSTransformationMatrix.identity - hit test matrix.
        initialTransformation = AGSTransformationMatrix.identity.subtractTransformation(matrix)

        return true
    }
    
    /// Starts device tracking.
    ///
    /// - Parameter completion: The completion handler called when start tracking completes.  If tracking starts successfully, the `error` property will be nil; if tracking fails to start, the error will be non-nil and contain the reason for failure.
    /// - Since: 100.6.0
    public func startTracking(_ locationTrackingMode: ARLocationTrackingMode, completion: ((_ error: Error?) -> Void)? = nil) {
        // We have a location data source that needs to be started.
        self.locationTrackingMode = locationTrackingMode
        if locationTrackingMode != .ignore,
            let locationDataSource = self.locationDataSource {
            locationDataSource.start { [weak self] (error) in
                if error == nil {
                    self?.finalizeStart()
                }
                completion?(error)
            }
        } else {
            // We're either ignoring the data source or there is no data source so continue with defaults.
            finalizeStart()
            completion?(nil)
        }
    }

    /// Suspends device tracking.
    /// - Since: 100.6.0
    public func stopTracking() {
        arSCNView.session.pause()
        locationDataSource?.stop()
        isTracking = false
    }
    
    // MARK: Private
    
    /// Operations that happen after device tracking has started.
    fileprivate func finalizeStart() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Run the ARSession.
            if self.isUsingARKit {
                self.arSCNView.session.run(self.arConfiguration, options: .resetTracking)
            }
            
            self.isTracking = true
        }
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
    
    /// Internal method to perform a hit test operation to get the transformation matrix representing the corresponding real-world point for `screenPoint`.
    ///
    /// - Parameter screenPoint: The screen point to determine the real world transformation matrix from.
    /// - Returns: An `AGSTransformationMatrix` representing the real-world point corresponding to `screenPoint`.
    fileprivate func internalHitTest(screenPoint: CGPoint) -> AGSTransformationMatrix? {
        // Use the `hitTest` method on ARSCNView to get the location of `screenPoint`.
        let results = arSCNView.hitTest(screenPoint, types: .existingPlaneUsingExtent)
        
        // Get the worldTransform from the first result; if there's no worldTransform, return nil.
        guard let worldTransform = results.first?.worldTransform else { return nil }
        
        // Create our hit test matrix based on the worldTransform location.
        // right now we ignore the orientation of the plane that was hit to find the point
        // since we only use horizontal planes, when we will start using vertical planes
        // we should stop suppressing the quaternion rotation to a null rotation (0,0,0,1)
        let hitTestMatrix = AGSTransformationMatrix(quaternionX: 0.0,
                                                    quaternionY: 0.0,
                                                    quaternionZ: 0.0,
                                                    quaternionW: 1.0,
                                                    translationX: Double(worldTransform.columns.3.x),
                                                    translationY: Double(worldTransform.columns.3.y),
                                                    translationZ: Double(worldTransform.columns.3.z))

        return hitTestMatrix
    }
}

// MARK: - ARSCNViewDelegate
extension ArcGISARView: ARSCNViewDelegate {
    // This is not implemented as we are letting ARKit create and manage nodes.
    // If you want to manage your own nodes, uncomment this and implement it in your code.
//    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
//        return arSCNViewDelegate?.renderer?(renderer, nodeFor: anchor)
//    }
    
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
        // If we aren't tracking yet, return.
        guard isTracking else { return }
        
        // Get transform from SCNView.pointOfView.
        guard let transform = arSCNView.pointOfView?.transform else { return }
        let cameraTransform = simd_double4x4(transform)
        
        let cameraQuat = simd_quatd(cameraTransform)
        let transformationMatrix = AGSTransformationMatrix(quaternionX: cameraQuat.vector.x,
                                                           quaternionY: cameraQuat.vector.y,
                                                           quaternionZ: cameraQuat.vector.z,
                                                           quaternionW: cameraQuat.vector.w,
                                                           translationX: cameraTransform.columns.3.x,
                                                           translationY: cameraTransform.columns.3.y,
                                                           translationZ: cameraTransform.columns.3.z)
        
        // Set the matrix on the camera controller.
        cameraController.transformationMatrix = initialTransformation.addTransformation(transformationMatrix)
        
        // Set FOV on camera.
        if let camera = arSCNView.session.currentFrame?.camera {
            let intrinsics = camera.intrinsics
            let imageResolution = camera.imageResolution
            
            // Get the device orientation, but don't allow non-landscape/portrait values.
            let deviceOrientation = UIDevice.current.orientation
            if deviceOrientation.isValidInterfaceOrientation {
                lastGoodDeviceOrientation = deviceOrientation
            }
            sceneView.setFieldOfViewFromLensIntrinsicsWithXFocalLength(intrinsics[0][0],
                                                                       yFocalLength: intrinsics[1][1],
                                                                       xPrincipal: intrinsics[2][0],
                                                                       yPrincipal: intrinsics[2][1],
                                                                       xImageSize: Float(imageResolution.width),
                                                                       yImageSize: Float(imageResolution.height),
                                                                       deviceOrientation: lastGoodDeviceOrientation)
        }

        // Render the Scene with the new transformation.
        sceneView.renderFrame()
        
        // Call our arSCNViewDelegate method.
        arSCNViewDelegate?.renderer?(renderer, willRenderScene: scene, atTime: time)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        arSCNViewDelegate?.renderer?(renderer, didRenderScene: scene, atTime: time)
    }
}

// MARK: - AGSLocationChangeHandlerDelegate
extension ArcGISARView: AGSLocationChangeHandlerDelegate {
    public func locationDataSource(_ locationDataSource: AGSLocationDataSource, headingDidChange heading: Double) {
        // Heading changed.
        if !isUsingARKit {
            // Not using ARKit, so update heading on the camera directly; otherwise, let ARKit handle heading changes.
            let currentCamera = sceneView.currentViewpointCamera()
            let camera = currentCamera.rotate(toHeading: heading, pitch: currentCamera.pitch, roll: currentCamera.roll)
            sceneView.setViewpointCamera(camera)
        }

        locationChangeHandlerDelegate?.locationDataSource?(locationDataSource, headingDidChange: heading)
    }
    
    public func locationDataSource(_ locationDataSource: AGSLocationDataSource, locationDidChange location: AGSLocation) {
        // Location changed.
        guard locationTrackingMode != .ignore, var locationPoint = location.position else { return }

        // The AGSCLLocationDataSource does not include altitude information from the CLLocation when
        // creating the `AGSLocation` geometry, so grab the altitude directly from the CLLocationManager.
        if let clLocationDataSource = locationDataSource as? AGSCLLocationDataSource {
            if let location = clLocationDataSource.locationManager.location,
                location.verticalAccuracy >= 0 {
                let altitude = location.altitude
                locationPoint = AGSPoint(x: locationPoint.x, y: locationPoint.y, z: altitude, spatialReference: locationPoint.spatialReference)
            } else {
                // We don't have a valid altitude, so use the old altitude.
                let oldLocationPoint = originCamera.location
                locationPoint = AGSPoint(x: locationPoint.x, y: locationPoint.y, z: oldLocationPoint.z, spatialReference: locationPoint.spatialReference)
            }
        }
        
        // Always set originCamera; then reset ARKit
        // Create a new camera based on our location and set it on the cameraController.
        // Note for the .initial tracking mode (or if we've yet to set an initial locatin),
        //   we create a new camera with the location and defaults for heading, pitch, roll.
        // For .continuous mode, we use the location and the old camera's heading, pitch, roll.
        if locationTrackingMode == .initial || !didSetInitialLocation {
            let newCamera = AGSCamera(location: locationPoint, heading: 0.0, pitch: 90.0, roll: 0.0)
            originCamera = newCamera
            didSetInitialLocation = true
        } else if locationTrackingMode == .continuous {
            originCamera = AGSCamera(location: locationPoint, heading: originCamera.heading, pitch: originCamera.pitch, roll: originCamera.roll)
        }
        
        // If we're using ARKit, reset its tracking.
        if isUsingARKit {
            arSCNView.session.run(arConfiguration, options: .resetTracking)
        }
        
        // Reset the camera controller's transformationMatrix to its initial state, the Idenity matrix.
        cameraController.transformationMatrix = .identity

        if locationTrackingMode != .continuous {
            // Stop the data source if the tracking mode is not continuous.
            locationDataSource.stop()
        }
        
        locationChangeHandlerDelegate?.locationDataSource?(locationDataSource, locationDidChange: location)
    }

    public func locationDataSource(_ locationDataSource: AGSLocationDataSource, statusDidChange status: AGSLocationDataSourceStatus) {
        // Status changed.
        locationChangeHandlerDelegate?.locationDataSource?(locationDataSource, statusDidChange: status)
    }
}

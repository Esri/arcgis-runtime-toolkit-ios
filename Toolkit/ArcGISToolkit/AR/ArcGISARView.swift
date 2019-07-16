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
    public let arSCNView = ARSCNView(frame: .zero)
    
    /// The initial transformation used for a table top experience.  Defaults to the Identity Matrix.
    public private(set) var initialTransformation = AGSTransformationMatrix.identity
    
    /// Denotes whether tracking location and angles has started.
    public private(set) var isTracking: Bool = false
    
    /// Denotes whether ARKit is being used to track location and angles.
    public private(set) var isUsingARKit: Bool = true

    /// The data source used to get device location.  Used either in conjuction with ARKit data or when ARKit is not present or not being used.
    public var locationDataSource: AGSCLLocationDataSource? {
        didSet {
            locationDataSource?.locationChangeHandlerDelegate = self
        }
    }

    /// The viewpoint camera used to set the initial view of the sceneView instead of the device's GPS location via the location data source.  You can use Key-Value Observing to track changes to the origin camera.
    @objc public dynamic var originCamera: AGSCamera? {
        didSet {
            guard let newCamera = originCamera else { return }
            // Set the camera as the originCamera on the cameraController and reset tracking.
            cameraController.originCamera = newCamera
            resetTracking()
        }
    }

    /// The view used to display ArcGIS 3D content.
    public let sceneView = AGSSceneView(frame: .zero)
    
    /// The translation factor used to support a table top AR experience.
    public var translationFactor: Double = 1.0 {
        didSet {
            cameraController.translationFactor = translationFactor
        }
    }
    
    /// The world tracking information used by `ARKit`.
    public var arConfiguration: ARConfiguration = {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.planeDetection = [.horizontal]
        return config
        }() {
        didSet {
            // If we're already tracking, reset tracking to use the new configuration.
            if isTracking {
                resetTracking()
            }
        }
    }
    
    /// We implement `ARSCNViewDelegate` methods, but will use `arSCNViewDelegate` to forward them to clients.
    weak public var arSCNViewDelegate: ARSCNViewDelegate?

    // MARK: Private properties
    
    /// The camera controller used to control the Scene.
    private let cameraController = AGSTransformationMatrixCameraController()
    
    /// Initial location from location data source.
    private var initialLocation: AGSPoint?
    
    /// Used when calculating framerate.
    private var lastUpdateTime: TimeInterval = 0
    
    /// A quaternion used to compensate for the pitch being 90 degrees on `ARKit`; used to calculate the current device transformation for each frame.
    private let compensationQuat: simd_quatd = simd_quatd(ix: (sin(45 / (180 / .pi))), iy: 0, iz: 0, r: (cos(45 / (180 / .pi))))
    
    /// Whether `ARKit` is supported on this device.
    private let deviceSupportsARKit: Bool = {
        return ARWorldTrackingConfiguration.isSupported
    }()

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
    /// - Parameters:
    ///   - renderVideoFeed: Whether to display the live camera image.
    ///   - tryUsingARKit: Whether or not to use ARKit, regardless if it's available.
    public convenience init(renderVideoFeed: Bool, tryUsingARKit: Bool){
        self.init(frame: .zero)
        
        // This overrides the `sharedInitialization()` isUsingARKit code
        isUsingARKit = tryUsingARKit && deviceSupportsARKit
        
        if !isUsingARKit || !renderVideoFeed {
            // User is not using ARKit, or they don't want to see video, so remove the arSCNView from the superView (it was added in sharedInitialization()).
            // This overrides the `sharedInitialization()` arSCNView code
            arSCNView.removeFromSuperview()
        }
        
        // Tell the sceneView we will be calling `renderFrame()` manually if we're using ARKit.
        // This overrides the `sharedInitialization()` `isManualRendering` code
        sceneView.isManualRendering = isUsingARKit
    }
    
    deinit {
        stopTracking()
    }
    
    /// Initialization code shared between all initializers.
    private func sharedInitialization(){
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
    
    // MARK: Public
    
    /// Determines the map point for the given screen point.
    ///
    /// - Parameter toLocation: The point in screen coordinates.
    /// - Returns: The map point corresponding to screenPoint.
    public func arScreenToLocation(screenPoint: CGPoint) -> AGSPoint {
        fatalError("arScreen(toLocation:) has not been implemented")
    }
    
    /// Resets the device tracking, using `originCamera` if it's not nil or the device's GPS location via the location data source.
    public func resetTracking() {
        initialLocation = nil
        startTracking()
    }
    
    /// Sets the initial transformation used to offset the originCamera.
    ///
    /// - Parameter initialTransformation: The initial transformation for originCamera offset.
    /// - Returns: Whether setting the `initialTransformation` succeeded or failed.
    public func setInitialTransformation(initialTransformation: AGSTransformationMatrix) -> Bool {
        fatalError("setInitialTransformation(initialTransformation:) has not been implemented")
    }
    
    /// Sets the initial transformation used to offset the originCamera.  The initial transformation is based on an AR point determined via existing plan hit detection from `screenPoint`.  If an AR point cannot be determined, this method will return `false`.
    ///
    /// - Parameter screenPoint: The screen point to determine the `initialTransformation` from..
    /// - Returns: Whether setting the `initialTransformation` succeeded or failed.
    public func setInitialTransformation(screenPoint: CGPoint) -> Bool {
        fatalError("setInitialTransformationPlacingOriginOnPlane(screenPoint:) has not been implemented")
    }

    /// Starts device tracking.
    public func startTracking(_ completion: ((_ error: Error?) -> Void)? = nil) {
        // We have a location data source that needs to be started.
        if let locationDataSource = self.locationDataSource {
            locationDataSource.start { [weak self] (error) in
                if error == nil {
                    self?.finalizeStart()
                }
                completion?(error)
            }
        }
        else {
            // No data source, continue with defaults.
            finalizeStart()
            completion?(nil)
        }
    }

    /// Suspends device tracking.
    public func stopTracking() {
        arSCNView.session.pause()
        locationDataSource?.stop()
        isTracking = false
    }
    
    // MARK: Private
    
    /// Operations that happen after device tracking has started.
    fileprivate func finalizeStart() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            // Run the ARSession.
            if strongSelf.isUsingARKit {
                strongSelf.arSCNView.session.run(strongSelf.arConfiguration, options: .resetTracking)
            }
            
            strongSelf.isTracking = true
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
        // If we aren't tracking yet, return.
        guard isTracking else { return }
        
        // Get transform from SCNView.pointOfView.
        guard let transform = arSCNView.pointOfView?.transform else { return }
        let cameraTransform = simd_double4x4(transform)
        
        // Calculate our final quaternion and create the new transformation matrix.
        let finalQuat:simd_quatd = simd_mul(compensationQuat, simd_quatd(cameraTransform))
        let transformationMatrix = AGSTransformationMatrix(quaternionX: finalQuat.vector.x,
                                                           quaternionY: finalQuat.vector.y,
                                                           quaternionZ: finalQuat.vector.z,
                                                           quaternionW: finalQuat.vector.w,
                                                           translationX: cameraTransform.columns.3.x,
                                                           translationY: -cameraTransform.columns.3.z,
                                                           translationZ: cameraTransform.columns.3.y)
        
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
                                                                       deviceOrientation: UIDevice.current.orientation)
        }

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

// MARK: - AGSLocationChangeHandlerDelegate
extension ArcGISARView: AGSLocationChangeHandlerDelegate {
    
    public func locationDataSource(_ locationDataSource: AGSLocationDataSource, headingDidChange heading: Double) {
        // Heading changed.
        if !isUsingARKit {
            // Not using ARKit, so update heading on the camera directly; otherwise, let ARKit handle heading changes.
            let currentCamera = sceneView.currentViewpointCamera()
            let camera = currentCamera.rotate(toHeading: heading, pitch: currentCamera.pitch, roll: currentCamera.roll)
            sceneView.setViewpointCamera(camera)
//            print("heading changed: \(heading)")
        }
    }
    
    public func locationDataSource(_ locationDataSource: AGSLocationDataSource, locationDidChange location: AGSLocation) {
        // Location changed.
        guard let locationPoint = location.position else { return }
        
        if initialLocation == nil {
            initialLocation = locationPoint
            
            // Create a new camera based on our location and set it on the cameraController.
            cameraController.originCamera = AGSCamera(location: locationPoint, heading: 0.0, pitch: 0.0, roll: 0.0)
        }
        else if !isUsingARKit {
            let camera = sceneView.currentViewpointCamera().move(toLocation: locationPoint)
            sceneView.setViewpointCamera(camera)
//            print("location changed: \(locationPoint), accuracy: \(location.horizontalAccuracy)")
        }
    }

    public func locationDataSource(_ locationDataSource: AGSLocationDataSource, statusDidChange status: AGSLocationDataSourceStatus) {
        // Status changed.
//        print("locationDataSource status changed: \(status.rawValue)")
    }
}

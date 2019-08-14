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
import ArcGISToolkit
import ArcGIS

class ARExample: UIViewController {
    
    typealias sceneInitFunction = () -> AGSScene
    typealias sceneInfoType = (sceneFunction: sceneInitFunction, label: String, tableTop: Bool)
    
    /// The scene creation functions plus labels and whehter it represents a table top experience.  The functions create a new scene and perform any necessary `ArcGISARView` initialization.  This allows for changing the scene and AR "mode" (table top or full-scale).
    private var sceneInfo: [sceneInfoType] = []
    
    /// The current scene info.
    private var currentSceneInfo: sceneInfoType? {
        didSet {
            guard let label = currentSceneInfo?.label else { return }
            statusViewController?.currentScene = label
        }
    }
    
    /// The `ArcGISARView` that displays the camera feed and handles ARKit functionality.
    private let arView = ArcGISARView(renderVideoFeed: true, tryUsingARKit: true)
    
    /// Denotes whether we've performed a hit test yet.
    private var didHitTest: Bool = false

    // View controller displaying current status of `ARExample`.
    private let statusViewController: ARStatusViewController? = {
        let storyBoard = UIStoryboard(name: "ARStatusViewController", bundle: nil)
        let vc = storyBoard.instantiateInitialViewController() as? ARStatusViewController
        return vc
    }()
    
    /// Used when calculating framerate.
    private var lastUpdateTime: TimeInterval = 0
    
    /// Overlay used to display user-placed graphics.
    private let graphicsOverlay: AGSGraphicsOverlay = {
        let overlay = AGSGraphicsOverlay()
        overlay.sceneProperties = AGSLayerSceneProperties(surfacePlacement: .absolute)
        return overlay
    }()
        
    /// View for displaying directions to the user.
    private let userDirectionsView = UserDirectionsView(effect: UIBlurEffect(style: .light))
    
    /// The observer for the `SceneView`'s `translationFactor` property.
    private var translationFactorObservation: NSKeyValueObservation?

    /// Denotes whether we're in calibration mode.
    private var isCalibrating = false
    private var calibrationView: CalibrationView?

    private var toolbar = UIToolbar(frame: .zero)
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set ourself as delegate so we can get ARSCNViewDelegate method calls.
        arView.arSCNViewDelegate = self
        
        // Set ourself as touch delegate so we can get touch events.
        arView.sceneView.touchDelegate = self
        
        // Disble user interactions on the sceneView.
        arView.sceneView.interactionOptions.isEnabled = false
        
        // Set ourself as the ARKit session delegate.
        arView.arSCNView.session.delegate = self
        
        // Add our graphics overlay to the sceneView.
        arView.sceneView.graphicsOverlays.add(graphicsOverlay)
        
        // Observe the `cameraController.translationFactor` property and update status when it changes.
        translationFactorObservation = arView.observe(\ArcGISARView.translationFactor, options: [.initial, .new]){ [weak self] arView, change in
            self?.statusViewController?.translationFactor = arView.translationFactor
        }
        
        // Add arView to the view and setup the constraints.
        view.addSubview(arView)
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
        // Add a Toolbar for changing the scene and showing the status view.
        toolbar = addToolbar()
        
        // Add the status view and setup constraints.
        if let statusVC = statusViewController {
            addChild(statusVC)
            view.addSubview(statusVC.view)
            statusVC.didMove(toParent: self)
            statusVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                statusVC.view.heightAnchor.constraint(equalToConstant: 110),
                statusVC.view.widthAnchor.constraint(equalToConstant: 350),
                statusVC.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                statusVC.view.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8)
                ])

            statusVC.view.alpha = 0.0
        }
        
        // Set up the `sceneInfo` array with our scene init functions and labels.
        sceneInfo.append(contentsOf: [(sceneFunction: streetsScene, label: "Streets - Full Scale", tableTop: false),
                                      (sceneFunction: imageryScene, label: "Imagery - Full Scale", tableTop: false),
                                      (sceneFunction: pointCloudScene, label: "Point Cloud - Tabletop", tableTop: true),
                                      (sceneFunction: yosemiteScene, label: "Yosemite - Tabletop", tableTop: true),
                                      (sceneFunction: borderScene, label: "US - Mexico Border - Tabletop", tableTop: true),
                                      (sceneFunction: emptyScene, label: "Empty - Full Scale", tableTop: false)])
        
        // Add the UserDirectionsView.
        addUserDirectionsView()
        
        // Add the CalibrationView.
        addCalibrationView()
        
        // Use the first sceneInfo to create and set the scene.
        currentSceneInfo = sceneInfo.first
        arView.sceneView.scene = currentSceneInfo?.sceneFunction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.startTracking { [weak self] (error) in
            if let error = error {
                self?.statusViewController?.errorMessage = error.localizedDescription
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        arView.stopTracking()
    }

    var originalGestures: [UIGestureRecognizer]?
    
    /// Initiatest scene location calibration.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func calibration(_ sender: UIBarButtonItem) {
        isCalibrating = !isCalibrating
        
        arView.sceneView.interactionOptions.isEnabled = isCalibrating
        userDirectionsView.updateUserDirections(/*isCalibrating ? "Calibrating...." : */"")
        
        // Do calibration work...
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.calibrationView?.alpha = (self?.isCalibrating ?? false) ? 1.0 : 0.0
        }
        
        // Do calibration work...
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.arView.sceneView.alpha = (self?.isCalibrating ?? false) ? 0.65 : 1.0
        }

//        if isCalibrating {
//            arView.stopTracking()
//        }
//        else {
//            // Done calibrating, start tracking again.
//            arView.startTracking { [weak self] (error) in
//                if let error = error {
//                    self?.statusViewController?.errorMessage = error.localizedDescription
//                }
//            }
//        }
    }

    /// Changes the scene to a newly selected scene.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func changeScene(_ sender: UIBarButtonItem){
        // Display an alert controller displaying the scenes to choose from.
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender
        sceneInfo.forEach { info in
            let action = UIAlertAction(title: info.label, style: .default, handler: { [weak self] (action) in
                // Set currentSceneInfo to the selected scene.
                self?.currentSceneInfo = info
                
                // Stop tracking, update the scene with the selected Scene and reset tracking.
                self?.arView.stopTracking()
                self?.arView.sceneView.scene = info.sceneFunction()
                if info.tableTop {
                    // Dim the SceneView until the user taps on a surface.
                    self?.arView.sceneView.alpha = 0.5
                }
                self?.arView.resetTracking()
                
                // Reset didHitTest variable
                self?.didHitTest = false
            })
            // Display current scene as disabled.
            action.isEnabled = !(info.label == currentSceneInfo?.label)
            alertController.addAction(action)
        }
        present(alertController, animated: true)
    }
    
    /// Dislays the status view controller
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func showStatus(_ sender: UIBarButtonItem){
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.statusViewController?.view.alpha = self?.statusViewController?.view.alpha == 1.0 ? 0.0 : 1.0
        }
    }
    
    private func addToolbar() -> UIToolbar {
        // Create a toolbar and add it to the arView.
        let toolbar = UIToolbar(frame: .zero)
        arView.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: arView.sceneView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: arView.sceneView.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: arView.sceneView.attributionTopAnchor)
            ])
        
        // Create a toolbar button for calibration.
        let calibrationItem = UIBarButtonItem(title: "Calibration", style: .plain, target: self, action: #selector(calibration(_:)))

        // Create a toolbar button to change the current scene.
        let sceneItem = UIBarButtonItem(title: "Change Scene", style: .plain, target: self, action: #selector(changeScene(_:)))
        
        // Create a toolbar button to display the status.
        let statusItem = UIBarButtonItem(title: "Status", style: .plain, target: self, action: #selector(showStatus(_:)))

        toolbar.setItems([calibrationItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          sceneItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          statusItem], animated: false)
        
        return toolbar
    }
}

// MARK: ARSCNViewDelegate
extension ARExample: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a custom object to visualize the plane geometry and extent.
        let plane = Plane(anchor: planeAnchor, in: arView.arSCNView)
        
        // Add the visualization to the ARKit-managed node so that it tracks
        // changes in the plane anchor as plane estimation continues.
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }
        
        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.node.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.node.simdPosition = planeAnchor.center
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        // Set the error message on the status vc.
        statusViewController?.errorMessage = errorMessage
        
        DispatchQueue.main.async { [weak self] in
            // Present an alert describing the error.
            let alertController = UIAlertController(title: "Could not start tracking.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Tracking", style: .default) { _ in
                self?.arView.startTracking()
            }
            alertController.addAction(restartAction)
            
            self?.present(alertController, animated: true)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // Set the tracking state on the status vc.
        statusViewController?.trackingState = camera.trackingState
        updateUserDirections(session.currentFrame!, trackingState: camera.trackingState)
    }
    xxx need willrenderScene
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // Calculate frame rate and set on the statuc vc.
        let frametime = time - lastUpdateTime
        statusViewController?.frameRate = Int((1.0 / frametime).rounded())
        lastUpdateTime = time
    }
}

// MARK: ARSessionDelegate
extension ARExample: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateUserDirections(frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateUserDirections(frame, trackingState: frame.camera.trackingState)
    }
}

// MARK: AGSGeoViewTouchDelegate
extension ARExample: AGSGeoViewTouchDelegate {
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        guard let sceneInfo = currentSceneInfo, !didHitTest else { return }

        let colors:[UIColor] = [.red, .blue, .yellow, .green]
        if sceneInfo.tableTop {
            // We're in table-top mode.  Place the scene at the given point by setting the initial transformation.
            if arView.setInitialTransformation(using: screenPoint) {
                // Show the SceneView now that the user has tapped on the surface.
                UIView.animate(withDuration: 0.5) { [weak self] in
                    self?.arView.sceneView.alpha = 1.0
                }
                userDirectionsView.updateUserDirections(nil)
                didHitTest = true
            }
        }
        else {
            // We're in full-scale AR mode. Get the real world location for screen point from arView.
            guard let point = arView.arScreenToLocation(screenPoint: screenPoint) else { return }
            
            
            print("point = \(point)")

            // Create and place a graphic at the real world location.
            let sphere = AGSSimpleMarkerSceneSymbol(style: .sphere, color: colors[hitCount], height: 0.25, width: 0.25, depth: 0.25, anchorPosition: .bottom)
            let shadow = AGSSimpleMarkerSceneSymbol(style: .sphere, color: .lightGray, height: 0.01, width: 0.25, depth: 0.25, anchorPosition: .center)
            let sphereGraphic = AGSGraphic(geometry: point, symbol: sphere, attributes: nil)
            let shadowGraphic = AGSGraphic(geometry: point, symbol: shadow, attributes: nil)
            graphicsOverlay.graphics.add(shadowGraphic
            
            )
            graphicsOverlay.graphics.add(sphereGraphic)
            hitCount += 1
            if hitCount > 3 {
                hitCount = 0
            }
        }
    }
}

// MARK: UIAdaptivePresentationControllerDelegate
extension ARExample: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // show presented controller as popovers even on small displays
        return .none
    }
}

// MARK: User Directions View
extension ARExample {
    
    func addUserDirectionsView() {
        // Add userDirectionsView to superView and setup constraints.
        view.addSubview(userDirectionsView)
        userDirectionsView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userDirectionsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            userDirectionsView.topAnchor.constraint(equalTo: view.topAnchor, constant: 88.0)
            ])
    }
    
    private func updateUserDirections(_ frame: ARFrame, trackingState: ARCamera.TrackingState) {
        var message = ""
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            if let sceneInfo = currentSceneInfo, sceneInfo.tableTop, !didHitTest {
                message = "Move the device around to detect horizontal surfaces."
            }
            break
        case .normal where !frame.anchors.isEmpty:
            if let sceneInfo = currentSceneInfo, sceneInfo.tableTop, !didHitTest {
                message = "Tap to place the Scene on a surface."
            }
            break
        case .notAvailable:
            message = "Location not available."
            break
        case .limited(let reason):
            switch(reason){
            case .excessiveMotion:
                message = "Try moving your device more slowly."
                break
            case .initializing:
                message = "Keep moving your device."
                break
            case .insufficientFeatures:
                message = "Try turning on more lights and moving around."
                break
            default:
                break
            }
        default:
            break
        }
        
        userDirectionsView.updateUserDirections(message)
    }
}

// MARK: Calibration View
extension ARExample {
    
    func addCalibrationView() {
        // Add calibrationView to superView and setup constraints.
        guard let cc = arView.sceneView.cameraController as? AGSTransformationMatrixCameraController else { return }
        calibrationView = CalibrationView(sceneView: arView.sceneView, cameraController: cc)
        guard let calibrationView = calibrationView else { return }
        view.addSubview(calibrationView)
        calibrationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            calibrationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            calibrationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            calibrationView.topAnchor.constraint(equalTo: view.topAnchor),
            calibrationView.bottomAnchor.constraint(equalTo: toolbar.topAnchor)
            ])
        
        calibrationView.alpha = 0.0
        
//        let elevationSlider: UISlider = {
//            let slider = UISlider(frame: .zero)
//            slider.minimumValue = -100.0
//            slider.maximumValue = 100.0
//            return slider
//        }()
//
//        let headingSlider: UISlider = {
//            let slider = UISlider(frame: .zero)
//            slider.minimumValue = -180.0
//            slider.maximumValue = 180.0
//            return slider
//        }()
//
//        addSubview(elevationSlider)
//        elevationSlider.addTarget(self, action: #selector(elevationChanged(_:)), for: .valueChanged)
//        elevationSlider.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            elevationSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
//            //            elevationSlider.topAnchor.constraint(equalTo: topAnchor, constant: 8),
//            elevationSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
//            ])
//
//        addSubview(headingSlider)
//        headingSlider.addTarget(self, action: #selector(headingChanged(_:)), for: .valueChanged)
//        headingSlider.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            headingSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
//            headingSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
//            //            elevationSlider.topAnchor.constraint(equalTo: topAnchor, constant: 8),
//            headingSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
//            ])

    }
}

// MARK: Scene creation methods
extension ARExample {
    //
    // These methods create the scenes and perform other intitialization required to set up the AR experiences.
    //
    
    /// Creates a scene based on the Streets base map.
    /// Mode:  Full-Scale AR
    ///
    /// - Returns: The new scene.
    private func streetsScene() -> AGSScene {
        
        // Create scene with the streets basemap.
        let scene = AGSScene(basemapType: .streets)
        scene.addElevationSource()
        
        // Set the location data source so we use our GPS location as the originCamera.
        arView.locationDataSource = AGSCLLocationDataSource()
        arView.originCamera = nil
        arView.translationFactor = 1
        return scene
    }
    
    /// Creates a scene based on the ImageryWithLabels base map.
    /// Mode:  Full-Scale AR
    ///
    /// - Returns: The new scene.
    private func imageryScene() -> AGSScene {
        
        // Create scene with the streets basemap.
        let scene = AGSScene(basemapType: .imageryWithLabels)
        scene.addElevationSource()
        
        // Set the location data source so we use our GPS location as the originCamera.
        arView.locationDataSource = AGSCLLocationDataSource()
        arView.originCamera = nil
        arView.translationFactor = 1
        return scene
    }
    
    /// Creates a scene based on a point cloud layer.
    /// Mode:  Tabletop AR
    ///
    /// - Returns: The new scene.
    private func pointCloudScene() -> AGSScene {
        // Create scene using a portalItem of the point cloud layer.
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "fc3f4a4919394808830cd11df4631a54")
        let layer = AGSPointCloudLayer(item: portalItem)
        let scene = AGSScene()
        scene.addElevationSource()
        scene.operationalLayers.add(layer)
        
        layer.load { [weak self] (error) in
            if let error = error {
                self?.statusViewController?.errorMessage = error.localizedDescription
                return
            }

            guard let extent = layer.fullExtent else { return }
            let center = extent.center
            
            // Create the origin camera at the center point of the data.  This will ensure the data is anchored to the table.
            let camera = AGSCamera(latitude: center.y, longitude: center.x, altitude: 0, heading: 0, pitch: 90.0, roll: 0)
            self?.arView.originCamera = camera
            self?.arView.translationFactor = 2000
        }
        
        // Clear the location data source, as we're setting the originCamera directly.
        arView.locationDataSource = nil
        return scene
    }
    
    /// Creates a scene centered on Yosemite National Park.
    /// Mode:  Tabletop AR
    ///
    /// - Returns: The new scene.
    private func yosemiteScene() -> AGSScene {
        let scene = AGSScene()
        scene.addElevationSource()
        
        // Create the Yosemite layer.
        let layer = AGSIntegratedMeshLayer(url: URL(string:"https://tiles.arcgis.com/tiles/FQD0rKU8X5sAQfh8/arcgis/rest/services/VRICON_Yosemite_Sample_Integrated_Mesh_scene_layer/SceneServer")!)
        scene.operationalLayers.add(layer)
        scene.load { [weak self, weak scene] (error) in
            if let error = error {
                self?.statusViewController?.errorMessage = error.localizedDescription
                return
            }
            
            // Get the center point of the layer's extent.
            guard let layer = scene?.operationalLayers.firstObject as? AGSLayer else { return }
            guard let extent = layer.fullExtent else { return }
            let center = extent.center
            
            scene?.baseSurface?.elevationSources.first?.load { (error) in
                if let error = error {
                    self?.statusViewController?.errorMessage = error.localizedDescription
                    return
                }
                
                // Find the elevation of the layer at the center point.
                scene?.baseSurface?.elevation(for: center, completion: { (elevation, error) in
                    if let error = error {
                        self?.statusViewController?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    // Create the origin camera at the center point and elevation of the data.  This will ensure the data is anchored to the table.
                    let camera = AGSCamera(latitude: center.y, longitude: center.x, altitude: elevation, heading: 0, pitch: 90, roll: 0)
                    self?.arView.originCamera = camera
                    self?.arView.translationFactor = 18000
                })
            }
        }
        
        // Clear the location data source, as we're setting the originCamera directly.
        arView.locationDataSource = nil
        return scene
    }
    
    /// Creates a scene centered the US-Mexico border.
    /// Mode:  Tabletop AR
    ///
    /// - Returns: The new scene.
    private func borderScene() -> AGSScene {
        let scene = AGSScene()
        scene.addElevationSource()
        
        // Create the border layer.
        let layer = AGSIntegratedMeshLayer(url: URL(string:"https://tiles.arcgis.com/tiles/FQD0rKU8X5sAQfh8/arcgis/rest/services/VRICON_SW_US_Sample_Integrated_Mesh_scene_layer/SceneServer")!)
        scene.operationalLayers.add(layer)
        scene.load { [weak self, weak scene] (error) in
            if let error = error {
                self?.statusViewController?.errorMessage = error.localizedDescription
                return
            }
            
            // Get the center point of the layer's extent.
            guard let layer = scene?.operationalLayers.firstObject as? AGSLayer else { return }
            guard let extent = layer.fullExtent else { return }
            let center = extent.center
            
            scene?.baseSurface?.elevationSources.first?.load { (error) in
                if let error = error {
                    self?.statusViewController?.errorMessage = error.localizedDescription
                    return
                }
                
                // Find the elevation of the layer at the center point.
                scene?.baseSurface?.elevation(for: center, completion: { (elevation, error) in
                    if let error = error {
                        self?.statusViewController?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    // Create the origin camera at the center point and elevation of the data.  This will ensure the data is anchored to the table.
                    let camera = AGSCamera(latitude: center.y, longitude: center.x, altitude: elevation, heading: 0, pitch: 90.0, roll: 0)
                    self?.arView.originCamera = camera
                    self?.arView.translationFactor = 1000
                })
            }
        }
        
        // Clear the location data source, as we're setting the originCamera directly.
        arView.locationDataSource = nil
        return scene
    }

    /// Creates an empty scene with an elevation source.
    /// Mode:  Full-Scale AR
    ///
    /// - Returns: The new scene.
    private func emptyScene() -> AGSScene {
        let scene = AGSScene()
        scene.addElevationSource()
        
        // Set the location data source so we use our GPS location as the originCamera.
        arView.locationDataSource = AGSCLLocationDataSource()
        arView.originCamera = nil
        arView.translationFactor = 1
        return scene
    }
}
    
// MARK: AGSScene extension.
extension AGSScene {
    /// Adds an elevation source to the given `scene`.
    ///
    /// - Parameter scene: The scene to add the elevation source to.
    public func addElevationSource() {
        let elevationSource = AGSArcGISTiledElevationSource(url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
        let surface = AGSSurface()
        surface.elevationSources = [elevationSource]
        surface.name = "baseSurface"
        surface.isEnabled = true
        surface.backgroundGrid.isVisible = false
        surface.navigationConstraint = .none
        baseSurface = surface
    }
}


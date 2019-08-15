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
    
    /// Denotes whether we've placed the scene in table top experiences.
    private var didPlaceScene: Bool = false

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

    /// View for displaying calibration controls to the user.
    private var calibrationView: CalibrationView?

    /// The toolbar used to display controls for calibration, changing scenes, and status.
    private var toolbar = UIToolbar(frame: .zero)

    // MARK: Initialization
    
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
        
        // Observe the `arView.translationFactor` property and update status when it changes.
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
        
        // Add a Toolbar for displaying user controls.
        addToolbar()
        
        // Add the status view and setup constraints.
        addStatusViewController()
        
        // Add the UserDirectionsView.
        addUserDirectionsView()
        
        // Add the CalibrationView.
        addCalibrationView()
        
        // Set up the `sceneInfo` array with our scene init functions and labels.
        sceneInfo.append(contentsOf: [(sceneFunction: streetsScene, label: "Streets - Full Scale", tableTop: false),
                                      (sceneFunction: imageryScene, label: "Imagery - Full Scale", tableTop: false),
                                      (sceneFunction: pointCloudScene, label: "Point Cloud - Tabletop", tableTop: true),
                                      (sceneFunction: yosemiteScene, label: "Yosemite - Tabletop", tableTop: true),
                                      (sceneFunction: borderScene, label: "US - Mexico Border - Tabletop", tableTop: true),
                                      (sceneFunction: emptyScene, label: "Empty - Full Scale", tableTop: false)])

        // Use the first sceneInfo to create and set the scene.
        currentSceneInfo = sceneInfo.first
        arView.sceneView.scene = currentSceneInfo?.sceneFunction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.startTracking { [weak self] (error) in
            self?.statusViewController?.errorMessage = error?.localizedDescription
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        arView.stopTracking()
    }

    // MARK: Toolbar button actions
    
    /// Initialize scene location/heading/elevation calibration.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func displayCalibration(_ sender: UIBarButtonItem) {
        // If the sceneView's alpha is 0.0, that means we are not in calibration mode and we need to start calibrating.
        let startCalibrating = (calibrationView?.alpha == 0.0)
        
        // Enable/disable sceneView touch interactions.
        arView.sceneView.interactionOptions.isEnabled = startCalibrating
        userDirectionsView.updateUserDirections(nil)
        
        // Display calibration view.
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.calibrationView?.alpha = startCalibrating ? 1.0 : 0.0
        }
        
        // Dim the sceneView if we're calibrating.
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.arView.sceneView.alpha = startCalibrating ? 0.65 : 1.0
        }
    }

    /// Allow users to change the current scene.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func changeScene(_ sender: UIBarButtonItem){
        // Display an alert controller displaying the scenes to choose from.
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender
        
        // Loop through all sceneInfos and add `UIAlertActions` for each.
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
                // Reset AR tracking and then start tracking.
                self?.arView.resetTracking()
                self?.arView.startTracking { [weak self] (error) in
                    self?.statusViewController?.errorMessage = error?.localizedDescription
                }
                
                // Reset didPlaceScene variable
                self?.didPlaceScene = false
            })
            // Display current scene as disabled.
            action.isEnabled = !(info.label == currentSceneInfo?.label)
            alertController.addAction(action)
        }
        present(alertController, animated: true)
    }
    
    /// Dislays the status view controller.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func showStatus(_ sender: UIBarButtonItem){
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.statusViewController?.view.alpha = self?.statusViewController?.view.alpha == 1.0 ? 0.0 : 1.0
        }
    }
    
    /// Sets up the toolbar and add it to the view.
    private func addToolbar() {
        // Add it to the arView and set up constraints.
        arView.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: arView.sceneView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: arView.sceneView.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: arView.sceneView.attributionTopAnchor)
            ])
        
        // Create a toolbar button for calibration.
        let calibrationItem = UIBarButtonItem(title: "Calibration", style: .plain, target: self, action: #selector(displayCalibration(_:)))

        // Create a toolbar button to change the current scene.
        let sceneItem = UIBarButtonItem(title: "Change Scene", style: .plain, target: self, action: #selector(changeScene(_:)))
        
        // Create a toolbar button to display the status.
        let statusItem = UIBarButtonItem(title: "Status", style: .plain, target: self, action: #selector(showStatus(_:)))

        toolbar.setItems([calibrationItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          sceneItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          statusItem], animated: false)
    }

    /// Set up the status view controller and adds it to the view.
    private func addStatusViewController() {
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
                self?.arView.startTracking { [weak self] (error) in
                    self?.statusViewController?.errorMessage = error?.localizedDescription
                }
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
        if let sceneInfo = currentSceneInfo, sceneInfo.tableTop, !didPlaceScene {
            // We're in table-top mode and haven't placed the scene yet.  Place the scene at the given point by setting the initial transformation.
            if arView.setInitialTransformation(using: screenPoint) {
                // Show the SceneView now that the user has tapped on the surface.
                UIView.animate(withDuration: 0.5) { [weak self] in
                    self?.arView.sceneView.alpha = 1.0
                }
                
                // Clear the user directions.
                userDirectionsView.updateUserDirections(nil)
                didPlaceScene = true
            }
        }
        else {
            // We're in full-scale AR mode or have already placed the scene. Get the real world location for screen point from arView.
            guard let point = arView.arScreenToLocation(screenPoint: screenPoint) else { return }

            // Create and place a graphic and shadown at the real world location.
            let shadowColor = UIColor.lightGray.withAlphaComponent(0.5)
            let shadow = AGSSimpleMarkerSceneSymbol(style: .sphere, color: shadowColor, height: 0.01, width: 0.25, depth: 0.25, anchorPosition: .center)
            let shadowGraphic = AGSGraphic(geometry: point, symbol: shadow, attributes: nil)
            graphicsOverlay.graphics.add(shadowGraphic)

            let sphere = AGSSimpleMarkerSceneSymbol(style: .sphere, color: .red, height: 0.25, width: 0.25, depth: 0.25, anchorPosition: .bottom)
            let sphereGraphic = AGSGraphic(geometry: point, symbol: sphere, attributes: nil)
            graphicsOverlay.graphics.add(sphereGraphic)
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
    
    /// Add user directions view to view and setup constraints.
    func addUserDirectionsView() {
        view.addSubview(userDirectionsView)
        userDirectionsView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userDirectionsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            userDirectionsView.topAnchor.constraint(equalTo: view.topAnchor, constant: 88.0)
            ])
    }
    
    /// Update the displayed message in the user directions view for the current frame and tracking state.
    ///
    /// - Parameters:
    ///   - frame: The current ARKit frame.
    ///   - trackingState: The current ARKit tracking state.
    private func updateUserDirections(_ frame: ARFrame, trackingState: ARCamera.TrackingState) {
        var message = ""
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            if let sceneInfo = currentSceneInfo, sceneInfo.tableTop, !didPlaceScene {
                message = "Move the device around to detect horizontal surfaces."
            }
            break
        case .normal where !frame.anchors.isEmpty:
            if let sceneInfo = currentSceneInfo, sceneInfo.tableTop, !didPlaceScene {
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
    
    /// Add the calibration view to the view and setup constraints.
    func addCalibrationView() {
        calibrationView = CalibrationView(sceneView: arView.sceneView, cameraController: arView.cameraController)
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
            self?.statusViewController?.errorMessage = error?.localizedDescription
            if let _ = error {
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
            self?.statusViewController?.errorMessage = error?.localizedDescription
            if let _ = error {
                return
            }
            
            // Get the center point of the layer's extent.
            guard let layer = scene?.operationalLayers.firstObject as? AGSLayer else { return }
            guard let extent = layer.fullExtent else { return }
            let center = extent.center
            
            scene?.baseSurface?.elevationSources.first?.load { (error) in
                self?.statusViewController?.errorMessage = error?.localizedDescription
                if let _ = error {
                    return
                }
                
                // Find the elevation of the layer at the center point.
                scene?.baseSurface?.elevation(for: center, completion: { (elevation, error) in
                    self?.statusViewController?.errorMessage = error?.localizedDescription
                    if let _ = error {
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
            self?.statusViewController?.errorMessage = error?.localizedDescription
            if let _ = error {
                return
            }
            
            // Get the center point of the layer's extent.
            guard let layer = scene?.operationalLayers.firstObject as? AGSLayer else { return }
            guard let extent = layer.fullExtent else { return }
            let center = extent.center
            
            scene?.baseSurface?.elevationSources.first?.load { (error) in
                self?.statusViewController?.errorMessage = error?.localizedDescription
                if let _ = error {
                    return
                }
                
                // Find the elevation of the layer at the center point.
                scene?.baseSurface?.elevation(for: center, completion: { (elevation, error) in
                    self?.statusViewController?.errorMessage = error?.localizedDescription
                    if let _ = error {
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


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
    
    /// The scene creation functions plus labels.  The functions create a new scene and perform any necessary `ArcGISARView` initialization.  This allows for changing the scene and AR "mode" (table top or full-scale).
    private var sceneInfo: [(sceneFunction: sceneInitFunction, label: String)] = []
    
    /// The current scene info.
    private var currentSceneInfo: (sceneFunction: sceneInitFunction, label: String)? {
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
        overlay.sceneProperties = AGSLayerSceneProperties(surfacePlacement: .relative)
        return overlay
    }()
        
    /// The observer for the `SceneView`'s `translationFactor` property
    private var translationFactorObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set ourself as delegate so we can get ARSCNViewDelegate method calls.
        arView.arSCNViewDelegate = self
        
        // Set ourself as touch delegate so we can get touch events.
        arView.sceneView.touchDelegate = self
        
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
        
        // Create a toolbar and add it to the arView.
        let toolbar = UIToolbar(frame: .zero)
        arView.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: arView.sceneView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: arView.sceneView.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: arView.sceneView.attributionTopAnchor)
            ])
        
        // Create a toolbar button to change the current scene.
        let sceneItem = UIBarButtonItem(title: "Change Scene", style: .plain, target: self, action: #selector(changeScene(_:)))
        
        // Create a toolbar button to display the status.
        let statusItem = UIBarButtonItem(title: "Status", style: .plain, target: self, action: #selector(showStatus(_:)))

        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          sceneItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          statusItem], animated: false)
        
        // Add the status view and setup constraints.
        
        if let statusVC = statusViewController {
            addChild(statusVC)
            view.addSubview(statusVC.view)
            statusVC.didMove(toParent: self)
            statusVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                statusVC.view.heightAnchor.constraint(equalToConstant: 110),
                statusVC.view.widthAnchor.constraint(equalToConstant: 350),
                statusVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                statusVC.view.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8)
                ])

            statusVC.view.alpha = 0.0
        }
        
        // Set up the `sceneInfo` array with our scene init functions and labels.
        sceneInfo.append(contentsOf: [(sceneFunction: streetsScene, label: "Streets - Full Scale"),
                                      (sceneFunction: pointCloudScene, label: "Point Cloud - Tabletop"),
                                      (sceneFunction: yosemiteScene, label: "Yosemite - Tabletop"),
                                      (sceneFunction: borderScene, label: "US - Mexico Border - Tabletop"),
                                      (sceneFunction: emptyScene, label: "Empty - Full Scale")])
        
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

    /// Changes the scene to a newly selected scene.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func changeScene(_ sender: UIBarButtonItem){
        // Display an alert controller displaying the scenes to choose from.
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender
        sceneInfo.forEach { (sceneFunction, label) in
            let action = UIAlertAction(title: label, style: .default, handler: { [weak self] (action) in
                // Set currentSceneInfo to the selected scene.
                self?.currentSceneInfo = (sceneFunction, label)
                
                // Stop tracking, update the scene with the selected Scene and reset tracking.
                self?.arView.stopTracking()
                self?.arView.sceneView.scene = sceneFunction()
                self?.arView.resetTracking()
                
                // Reset didHitTest variable
                self?.didHitTest = false
            })
            // Display current scene as disabled.
            action.isEnabled = !(label == currentSceneInfo?.label)
            alertController.addAction(action)
        }
        present(alertController, animated: true)
    }
    
    /// Dislays the status view controller
    @objc func showStatus(_ sender: UIBarButtonItem){
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.statusViewController?.view.alpha = self?.statusViewController?.view.alpha == 1.0 ? 0.0 : 1.0
        }
    }
}

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
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // Calculate frame rate and set on the statuc vc.
        let frametime = time - lastUpdateTime
        statusViewController?.frameRate = Int((1.0 / frametime).rounded())
        lastUpdateTime = time
    }
}

extension ARExample: AGSGeoViewTouchDelegate {
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        guard !didHitTest else { return }
        
        if let _ = arView.locationDataSource {
            // We have a location data source, so we're in full-scale AR mode.
            // Get the real world location for screen point from arView.
            guard let point = arView.arScreenToLocation(screenPoint: screenPoint) else { return }

            let sym = AGSSimpleMarkerSceneSymbol(style: .sphere, color: .yellow, height: 1.0, width: 1.0, depth: 1.0, anchorPosition: .bottom)
            let graphic = AGSGraphic(geometry: point, symbol: sym, attributes: nil)
            graphicsOverlay.graphics.add(graphic)
        }
        else {
            // We do not have a location data source, so we're in table-top mode.
            if arView.setInitialTransformation(using: screenPoint) {
                didHitTest = true
            }
        }
    }
}

extension ARExample: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // show presented controller as popovers even on small displays
        return .none
    }
}

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
        addElevationSource(toScene: scene)
        
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
        addElevationSource(toScene: scene)
        scene.operationalLayers.add(layer)
        
        layer.load { [weak self] (error) in
            if let error = error {
                self?.statusViewController?.errorMessage = error.localizedDescription
                return
            }

            guard let extent = layer.fullExtent else { return }
            let center = extent.center
            
            // Create the origin camera at the center point of the data.  This will ensure the data is anchored to the table.
            let camera = AGSCamera(latitude: center.y, longitude: center.x, altitude: 0, heading: 0, pitch: 0, roll: 0)
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
        addElevationSource(toScene: scene)
        
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
                    let camera = AGSCamera(latitude: center.y, longitude: center.x, altitude: elevation, heading: 0, pitch: 0, roll: 0)
                    self?.arView.originCamera = camera
                    self?.arView.translationFactor = 1000
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
        addElevationSource(toScene: scene)
        
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
                    let camera = AGSCamera(latitude: center.y, longitude: center.x, altitude: elevation, heading: 0, pitch: 0, roll: 0)
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
        addElevationSource(toScene: scene)
        
        // Set the location data source so we use our GPS location as the originCamera.
        arView.locationDataSource = AGSCLLocationDataSource()
        arView.originCamera = nil
        arView.translationFactor = 1
        return scene
    }
    
    /// Adds an elevation source to the given `scene`.
    ///
    /// - Parameter scene: The scene to add the elevation source to.
    private func addElevationSource(toScene scene: AGSScene) {
        let elevationSource = AGSArcGISTiledElevationSource(url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
        let surface = AGSSurface()
        surface.elevationSources = [elevationSource]
        surface.name = "baseSurface"
        surface.isEnabled = true
        surface.backgroundGrid.isVisible = false
        scene.baseSurface = surface
    }
}

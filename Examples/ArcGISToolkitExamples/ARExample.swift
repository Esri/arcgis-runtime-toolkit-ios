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
//import ArcGISToolkit
//import ArcGIS

open class ARExample: UIViewController {
    
    var featureLayer: AGSFeatureLayer?
    let graphicsOverlay = AGSGraphicsOverlay()
    let basemapSwitch = UISwitch(frame: .zero)
    let graphicsSwitch = UISwitch(frame: .zero)

    public let arView = ArcGISARView(frame: CGRect.zero)
//    public let arView = ArcGISARView(renderVideoFeed: false)
//    public let arView = ArcGISARSensorView(renderVideoFeed: true)

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        arView.frame = view.bounds
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        arView.sceneView.scene = scene()
//        arView.sceneView.alpha = 0.5
        
        // option to turn background on/off
        basemapSwitch.isOn = true
        
        basemapSwitch.translatesAutoresizingMaskIntoConstraints = false
        arView.sceneView.addSubview(basemapSwitch)
        NSLayoutConstraint.activate([
            basemapSwitch.trailingAnchor.constraint(equalTo: arView.sceneView.trailingAnchor, constant: -24),
            basemapSwitch.topAnchor.constraint(equalTo: arView.sceneView.topAnchor, constant: 88)
            ])
        basemapSwitch.isOn = arView.sceneView.isBackgroundTransparent
        basemapSwitch.addTarget(self, action: #selector(switchBasemap), for: .valueChanged)
        
        // option to turn background on/off
        graphicsSwitch.isOn = false
        
        graphicsSwitch.translatesAutoresizingMaskIntoConstraints = false
        arView.sceneView.addSubview(graphicsSwitch)
        NSLayoutConstraint.activate([
            graphicsSwitch.trailingAnchor.constraint(equalTo: arView.sceneView.trailingAnchor, constant: -24),
            graphicsSwitch.topAnchor.constraint(equalTo: basemapSwitch.bottomAnchor, constant: 12)
            ])
        graphicsSwitch.isOn = arView.sceneView.isBackgroundTransparent
        graphicsSwitch.addTarget(self, action: #selector(switchGraphics), for: .valueChanged)

    }
    
    override open func viewDidAppear(_ animated: Bool) {
        arView.startTracking()
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        arView.stopTracking()
    }
    
    private func scene() -> AGSScene {

        // create scene
        let scene = AGSScene(basemapType: .streets)
//        let scene = AGSScene()

        // create elevation surface
        let elevationSource = AGSArcGISTiledElevationSource(url: URL(string: "http://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
        let surface = AGSSurface()
        surface.elevationSources = [elevationSource]
        surface.name = "baseSurface"
        surface.isEnabled = true
        surface.backgroundGrid.isVisible = false
        scene.baseSurface = surface

        // add data #1
//        let ft = AGSServiceFeatureTable(url: URL(string: "https://services2.arcgis.com/2B0gmGCMCH3iKkax/arcgis/rest/services/MinneapolisStPaulPOI/FeatureServer/0")!)
//        featureLayer = AGSFeatureLayer(featureTable: ft)
////        arView.sceneView.scene?.operationalLayers.add(featureLayer!)
//        addGraphicsToOverlay()
        
        // add data #2
//        let sceneLayer = AGSArcGISSceneLayer(name: "sandiegostage")
//        arView.sceneView.scene?.operationalLayers.add(sceneLayer)
        
        return scene
    }
    
    func addGraphicsToOverlay() {
        // add graphics overlay to scene
        
        arView.sceneView.graphicsOverlays.add(graphicsOverlay)
        let qp = AGSQueryParameters()
        
        //        upperleft: 44.950751; -93.323193
        //        lr: 44.929669, -93.287659
        
        let envelope = AGSEnvelope(xMin: -93.323193, yMin: 44.929669, xMax: -93.287659, yMax: 44.950751, spatialReference: .wgs84())
        qp.geometry = envelope
        qp.spatialRelationship = .contains
        
        //        self.featureLayer?.selectFeatures(withQuery: qp, mode: .new, completion: { (queryResult, error) in
        self.featureLayer?.featureTable?.load(completion: { (error) in
            self.featureLayer?.featureTable?.queryFeatures(with: qp, completion: { (queryResult, error) in
                if let queryResult = queryResult {
                    let markerSymbol = AGSSimpleMarkerSceneSymbol(style: .diamond, color: .blue, height: 50, width: 50, depth: 50, anchorPosition: .bottom)
                    for feature in queryResult.featureEnumerator() {
                        if let feature = feature as? AGSArcGISFeature {
                            feature.load(completion: { (error) in
                                guard error == nil else { return }
                                let compositeSymbol = AGSCompositeSymbol()
                                let text = feature.attributes.object(forKey: "Name") as? String ?? ""
                                let textSymbol = AGSTextSymbol(text: text, color: .red, size: 36.0, horizontalAlignment: .center, verticalAlignment: .bottom)
                                
                                compositeSymbol.symbols = [markerSymbol, textSymbol]
                                if let featurePoint = feature.geometry as? AGSPoint {
                                    let point = AGSPoint(x: featurePoint.x, y: featurePoint.y, z: 100, spatialReference: feature.geometry?.spatialReference)
                                    let graphic = AGSGraphic(geometry: point, symbol: compositeSymbol, attributes: feature.attributes as? [String : Any])
                                    self.graphicsOverlay.graphics.add(graphic)
                                }
                            })
                        }
                    }
                }
            })
        })
    }
    
    @objc func switchBasemap() {
        arView.sceneView.scene?.basemap?.baseLayers.forEach({ (baseLayer) in
            guard let layer = baseLayer as? AGSLayer else { return }
            layer.isVisible = basemapSwitch.isOn
            arView.sceneView.scene?.baseSurface?.backgroundGrid.isVisible = basemapSwitch.isOn
        })
        //        sceneView.atmosphereEffect = backgroundSwitch.isOn ? .none : .realistic
    }
    
    @objc func switchGraphics() {
        guard let overlay = arView.sceneView.graphicsOverlays.firstObject as? AGSGraphicsOverlay else { return }
        overlay.isVisible = graphicsSwitch.isOn
    }
}


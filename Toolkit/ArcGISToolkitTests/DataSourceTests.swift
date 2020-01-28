//
// Copyright 2020 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
import ArcGISToolkit
import ArcGIS

class DataSourceTests: XCTestCase {
    /// Tests the creation of a `DataSource` using a list of `AGSLayerContent`.
    func testDataSourceLayers() {
        let layers = generateLayerContents()
        let dataSource = DataSource(layers: layers)
        XCTAssertEqual(layers.count, dataSource.layerContents.count)
    }
    
    /// Tests the creation of a `DataSource` using an `AGSMapView` by verifying the `layerContents` property returns the correct number of `AGSLayerContent`.
    func testDataSourceMapView() {
        let mapView = AGSMapView()
        let map = AGSMap(basemap: .streets())
        mapView.map = map
        
        let layerContents = generateLayerContents()
        map.operationalLayers.addObjects(from: layerContents)

        // Wait for the map to load.  This allows the observers to be set up.
        XCTLoad(map)
        
        // Create the dataSource.
        let dataSource = DataSource(geoView: mapView)
        XCTAssertEqual(layerCount(map: map), dataSource.layerContents.count)
    }
    
    /// Tests the creation of the `dataSource` using an `AGSSceneView` by verifying the `layerContents` property returns the correct number of layerContents
    func testlayerContentsSceneView() {
        let sceneView = AGSSceneView()
        let scene = AGSScene(basemap: .streets())
        sceneView.scene = scene

        let layerContents = generateLayerContents()
        scene.operationalLayers.addObjects(from: layerContents)

        // Wait for the scene to load.  This allows the observers to be set up.
        XCTLoad(scene)

        // Create the dataSource.
        let dataSource = DataSource(geoView: sceneView)
        XCTAssertEqual(layerCount(scene: scene), dataSource.layerContents.count)
    }
    
    /// Tests boundary conditions by verifying the `layerContents` property returns the correct number of layerContents
    func testBoundaryConditions() {
        //
        // Test with no base map.
        //
        let sceneView = AGSSceneView()
        let scene = AGSScene()
        sceneView.scene = scene

        let layerContents = generateLayerContents()
        scene.operationalLayers.addObjects(from: layerContents)

        // Wait for the scene to load.  This allows the observers to be set up.
        XCTLoad(scene)

        // Create the dataSource.
        var dataSource = DataSource(geoView: sceneView)
        XCTAssertEqual(layerCount(scene: scene), dataSource.layerContents.count)
        
        //
        // Test with no operational layers.
        //
        var mapView = AGSMapView()
        var map = AGSMap(basemap: .streets())
        mapView.map = map
        
        // Wait for the map to load.  This allows the observers to be set up.
        XCTLoad(map)
        
        // Create the dataSource.
        dataSource = DataSource(geoView: mapView)
        XCTAssertEqual(layerCount(map: map), dataSource.layerContents.count)
        
        //
        // Test with no operational or base map layers.
        //
        mapView = AGSMapView()
        map = AGSMap(spatialReference: .wgs84())
        mapView.map = map
        
        // Wait for the map to load.  This allows the observers to be set up.
        XCTLoad(map)
        
        // Create the dataSource.
        dataSource = DataSource(geoView: mapView)
        XCTAssertEqual(layerCount(map: map), dataSource.layerContents.count)
        XCTAssertEqual(dataSource.layerContents.count, 0)

        //
        // Test with empty layers array.
        //
        let emptyDataSource = DataSource(layers: [])
        XCTAssertEqual(emptyDataSource.layerContents.count, 0)
    }

    // MARK: Internal
    
    /// Generates a list of predefined layerContents for testing.
    func generateLayerContents() -> [AGSLayerContent] {
        let featureTables: [AGSFeatureTable] = [
            AGSServiceFeatureTable(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/0")!),
            AGSServiceFeatureTable(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/8")!),
            AGSServiceFeatureTable(url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Energy/Geology/FeatureServer/9")!)
        ]
        
        var layers = [AGSLayerContent]()
        featureTables.forEach { (featureTable) in
            layers.append(AGSFeatureLayer(featureTable: featureTable))
        }
        
        return layers
    }
    
    /// Counts the number of layers in a map's operational layers and base map.
    /// - Parameter map: The map to count the layers in.
    func layerCount(map: AGSMap) -> Int {
        return layerCount(operationalLayers: map.operationalLayers as! [AGSLayer], basemap: map.basemap)
    }
    
    /// Counts the number of layers in a map's operational layers and base map.
    /// - Parameter scene: The scene to count the layers in.
    func layerCount(scene: AGSScene) -> Int {
        return layerCount(operationalLayers: scene.operationalLayers as! [AGSLayer], basemap: scene.basemap)
    }

    /// Counts the total number of layers in an operationalLayers array and basemap.
    /// - Parameter operationalLayers: The operational layers to count.
    /// - Parameter basemap: The base map containing the base and reference layers to count
    func layerCount(operationalLayers: [AGSLayer], basemap: AGSBasemap?) -> Int {
        var count = operationalLayers.count
        if let refLayers = basemap?.referenceLayers {
            count += refLayers.count
        }

        if let baseLayers = basemap?.baseLayers {
            count += baseLayers.count
        }
        
        return count
    }
}

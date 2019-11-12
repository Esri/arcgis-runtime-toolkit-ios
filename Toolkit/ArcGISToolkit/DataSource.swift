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
import ArcGIS

/// The data source is initialized with either an array of `AGSLayerContents` or an `AGSGeoView` of which the operational and base map layers (`AGSLayerConents`) are identified.
public class DataSource: NSObject {
    /// Returns a `DataSource` initialized with the given `AGSLayerContent` array..
    /// - Parameter layers: <#layers description#>
    /// - Since: 100.7.0
    public init(layers: [AGSLayerContent]) {
        super.init()
        layerContents.append(contentsOf: layers)
    }
    
    /// Returns a `DataSource` initialized with the operational and base map layers of a map or scene in an `AGSGeoView`.
    /// - Parameter geoView: The `AGSGeoView` containing the map/scene's operational and base map layers.
    /// - Since: 100.7.0
    public init(geoView: AGSGeoView) {
        super.init()
        geoViewDidChange(nil)
    }
    
    /// The `AGSGeoView` containing either an `AGSMap` or `AGSScene` with the `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var geoView: AGSGeoView? {
        didSet {
            geoViewDidChange(oldValue)
        }
    }

    /// The list of all layers used to generate the TOC/Legend, read-only.  It contains both the operational layers of the map/scene and
    /// the reference and base layers of the basemap.  The order of the layer contents is the order in which they are drawn
    /// in a map or scene:  bottom up (the first layer in the array is at the bottom and drawn first; the last layer is at the top and drawn last).
    /// - Since: 100.7.0
    public private(set) var layerContents = [AGSLayerContent]()
    
    private func geoViewDidChange(_ previousGeoView: AGSGeoView?) {
        var basemap: AGSBasemap?
        if let mapView = geoView as? AGSMapView {
            mapView.map?.load { [weak self] (error) in
                guard let self = self, let mapView = self.geoView as? AGSMapView else { return }
                if let error = error {
                    print("Error loading map: \(error)")
                } else {
                    self.layerContents = mapView.map?.operationalLayers as? [AGSLayerContent] ?? []
                    basemap = mapView.map?.basemap
                }
            }
        } else if let sceneView = geoView as? AGSSceneView {
            sceneView.scene?.load { [weak self] (error) in
                guard let self = self, let sceneView = self.geoView as? AGSSceneView else { return }
                if let error = error {
                    print("Error loading map: \(error)")
                } else {
                    self.layerContents = sceneView.scene?.operationalLayers as? [AGSLayerContent] ?? []
                    basemap = sceneView.scene?.basemap
                }
            }
        }

        // Check if we have a basemap.
        if let basemap = basemap {
            basemap.load { [weak self] (error) in
                if let error = error {
                    print("Error loading base map: \(error)")
                } else {
                    // Append any reference layers to the `layerContents` array.
                    if let referenceLayers = basemap.referenceLayers as? [AGSLayerContent] {
                        self?.layerContents.append(contentsOf: referenceLayers)
                    }
                    
                    // Insert any base layers at the beginning of the `layerContents` array.
                    if let baseLayers = basemap.baseLayers as? [AGSLayerContent] {
                        self?.layerContents.insert(contentsOf: baseLayers, at: 0)
                    }
                }
            }
        }
    }
}

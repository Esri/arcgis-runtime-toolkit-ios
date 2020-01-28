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

import UIKit
import ArcGIS

/// The data source is used to represent an array of `AGSLayerContent` for use in a variety of
/// implementations. It is initialized with either an array of `AGSLayerContent`
/// or an `AGSGeoView` from whose `AGSMap` or `AGSScene` the  operational and
/// base map layers (`AGSLayerContent`) are extracted.
public class DataSource: NSObject {
    /// Returns a `DataSource` initialized with the given `AGSLayerContent` array..
    /// - Parameter layers: The array of `AGSLayerContent`.
    /// - Since: 100.8.0
    public init(layers: [AGSLayerContent]) {
        super.init()
        layerContents.append(contentsOf: layers)
    }
    
    /// Returns a `DataSource` initialized with the operational and base map layers of a
    /// map or scene in an `AGSGeoView`.
    /// - Parameter geoView: The `AGSGeoView` containing the map/scene's
    /// operational and base map layers.
    /// - Since: 100.8.0
    public init(geoView: AGSGeoView) {
        super.init()
        self.geoView = geoView
        geoViewDidChange()
    }
    
    /// The `AGSGeoView` containing either an `AGSMap` or `AGSScene` with the operational and
    /// base map layers to use as data.
    /// If the `DataSource` was initialized with an array of `AGSLayerContent`, `goeView` will be nil.
    /// - Since: 100.8.0
    public private(set) var geoView: AGSGeoView? {
        didSet {
            geoViewDidChange()
        }
    }

    /// The list of all layers used to generate the TOC/Legend, read-only.  It contains both the
    /// operational layers of the map/scene and the reference and base layers of the basemap.
    /// The order of the layer contents is the order in which they are drawn
    /// in a map or scene:  bottom up (the first layer in the array is at the bottom and drawn first; the last
    /// layer is at the top and drawn last).
    /// - Since: 100.8.0
    public private(set) var layerContents = [AGSLayerContent]()
    
    private func geoViewDidChange() {
        if let mapView = geoView as? AGSMapView {
            mapView.map?.load { [weak self] (error) in
                guard let self = self,
                    let mapView = self.geoView as? AGSMapView else { return }
                if let error = error {
                    print("Error loading map: \(error)")
                } else {
                    self.layerContents = mapView.map?.operationalLayers as? [AGSLayerContent] ?? []
                    self.appendBasemap(mapView.map?.basemap)
                }
            }
        } else if let sceneView = geoView as? AGSSceneView {
            sceneView.scene?.load { [weak self] (error) in
                guard let self = self,
                    let sceneView = self.geoView as? AGSSceneView else { return }
                if let error = error {
                    print("Error loading scene: \(error)")
                } else {
                    self.layerContents = sceneView.scene?.operationalLayers as? [AGSLayerContent] ?? []
                    self.appendBasemap(sceneView.scene?.basemap)
                }
            }
        }
    }
    
    private func appendBasemap(_ basemap: AGSBasemap?) {
        guard let basemap = basemap else { return }
        
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

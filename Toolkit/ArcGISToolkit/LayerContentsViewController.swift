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

/// Defines how to display layers in the table.
/// - Since: 100.7.0
public enum ConfigurationStyle {
    // Displays all layers.
    case allLayers
    // Displays all layers, grouping layers into three sections: 1. visible & in-scale; 2. out-of-scale; 3. not visible.
    case allLayersGrouped
    // Only displays layers that are in scale and visible.
    case visibleLayersAtScale
}

/// Configuration is an protocol (interface) that drives how to format the layer contents table.
/// - Since: 100.7.0
public protocol Configuration {
    /// Specifies the `Style` applied to the table.
    var layersStyle: ConfigurationStyle { get }
    
    /// Specifies whether layer/sublayer cells will include a switch used to toggle visibility of the layer.
    var allowToggleVisibility: Bool { get }
    
    /// Specifies whether layer/sublayer cells will include a chevron used show/hide the contents of a layer/sublayer.
    var allowLayersAccordion: Bool { get }
    
    /// Specifies whether layers/sublayers should show it's symbols.
    var showSymbology: Bool { get }
    
    /// Specifies whether to respect the layer order or to reverse the layer order supplied.
    /// If provided a geoView, the layer will include the basemap.
    /// - If `false`, the top layer's information appears at the top of the legend and the base map's layer information appears at the bottom of the legend.
    /// - If `true`, this order is reversed.
    var respectLayerOrder: Bool { get }
    
    /// Specifies whether to respect `LayerConents.showInLegend` when deciding whether to include the layer.
    var respectShowInLegend: Bool { get }
    
    /// Specifies whether to include separators between layer cells.
    var showRowSeparator: Bool { get }
    
    /// The title of the view.
    var title: String { get }
}

/// Describes a `LayerContentsViewController` for a list of Layers, possibly contained in a GeoView.
/// The `LayerContentsViewController` can be styled to that of a legend, table of contents or some custom derivative.
/// - Since: 100.7.0
public class LayerContentsViewController: UIViewController {
    /// Provide an out of the box TOC configuration.
    public struct TableOfContents: Configuration {
        public var layersStyle = ConfigurationStyle.allLayers
        public var  allowToggleVisibility: Bool = true
        public var allowLayersAccordion: Bool = true
        public var showSymbology: Bool = true
        public var respectLayerOrder: Bool = false
        public var respectShowInLegend: Bool = false
        public var showRowSeparator: Bool = true
        public var title: String = "Table of Contents"
    }
    
    /// Provide an out of the box Legend configuration.
    public struct Legend: Configuration {
        public var layersStyle: ConfigurationStyle = .allLayersGrouped
        public var allowToggleVisibility: Bool = false
        public var allowLayersAccordion: Bool = false
        public var showSymbology: Bool = true
        public var respectLayerOrder: Bool = false
        public var respectShowInLegend: Bool = true
        public var showRowSeparator: Bool = false
        public var title: String = "Legend"
    }
    
    /// The `DataSource` specifying the list of `AGSLayerContent` to display.
    public var dataSource: DataSource? = nil {
        didSet {
            generateLayerList()
        }
    }
    
    /// The default configuration is a TOC. Setting a new configuration redraws the view.
    public var config: Configuration = TableOfContents() {
        didSet {
        }
    }
    
    private var layerContentsTableViewController: LayerContentsTableViewController?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        // get the bundle and then the storyboard
        let bundle = Bundle(for: LayerContentsTableViewController.self)
        let storyboard = UIStoryboard(name: "LayerContentsTableViewController", bundle: bundle)
        
        // create the legend VC from the storyboard
        layerContentsTableViewController = storyboard.instantiateInitialViewController() as? LayerContentsTableViewController
        
        if let tableViewController = layerContentsTableViewController {
            // Setup our internal LayerContentsTableViewController and add it as a child.
            addChild(tableViewController)
            view.addSubview(tableViewController.view)
            tableViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tableViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                tableViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            tableViewController.didMove(toParent: self)
        }
        
        // generate and set the layerContent list.
        generateLayerList()
    }
    
    /// Uses the DataSource to generate the list of `AGSLayerContent` to include in the table view.
    private func generateLayerList() {
        layerContentsTableViewController?.layerContents = dataSource?.layerContents ?? [AGSLayerContent]()
    }
}

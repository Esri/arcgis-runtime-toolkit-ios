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
enum ConfigurationStyle {
  // Displays all layers.
  case allLayers
  // Displays all layers, grouping layers into three sections: 1. visible & in-scale; 2. out-of-scale; 3. not visible.
  case allLayersGrouped
  // Only displays layers that are in scale and visible.
  case visibleLayersAtScale
}

/// Configuration is an protocol (interface) that drives how to format the layer contents table.
/// - Since: 100.7.0
protocol Configuration {
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
class LayerContentsViewController: UIViewController {
    
    /// Provide an out of the box TOC configuration.
    struct TableOfContents: Configuration {
      let layersStyle: ConfigurationStyle = .allLayers
      let allowToggleVisibility: Bool = true
      let allowLayersAccordion: Bool = true
      let showSymbology: Bool = true
      let respectLayerOrder: Bool = false
      let respectShowInLegend: Bool = false
      let showRowSeparator: Bool = true
      let title: String = "Table of Contents"
    }

    /// Provide an out of the box Legend configuration.
    struct Legend: Configuration {
      let layersStyle: ConfigurationStyle = .allLayersGrouped
      let allowToggleVisibility: Bool = false
      let allowLayersAccordion: Bool = false
      let showSymbology: Bool = true
      let respectLayerOrder: Bool = false
      let respectShowInLegend: Bool = true
      let showRowSeparator: Bool = false
      let title: String = "Legend"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}

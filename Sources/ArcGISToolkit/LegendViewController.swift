// Copyright 2017 Esri.

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

public class LegendViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    public var geoView: AGSGeoView? {
        didSet {
            if geoView != nil {
                if let mapView = geoView as? AGSMapView {
                    mapView.map?.load { [weak self] (_) in
                        if let basemap = mapView.map?.basemap {
                            basemap.load { (_) in
                                self?.updateLayerData()
                            }
                        }
                    }
                } else if let sceneView = geoView as? AGSSceneView {
                    sceneView.scene?.load(completion: {[weak self] (_) in
                        if let basemap = sceneView.scene?.basemap {
                            basemap.load(completion: { (_) in
                                self?.updateLayerData()
                            })
                        }
                    })
                }
                
                // set layerViewStateChangedHandler
                if let geoView = geoView {
                    geoView.layerViewStateChangedHandler = { [weak self] (_, _) in
                        DispatchQueue.main.async {
                            self?.updateLegendArray()
                        }
                    }
                }
            }
        }
    }
    
    public var respectScaleRange: Bool = true {
        didSet {
            updateLayerData()
        }
    }
    public var reverseLayerOrder: Bool = false {
        didSet {
            updateLayerData()
        }
    }

    // the tableView used to display the legend
    @IBOutlet private var tableView: UITableView?
    
    // dictionary of legend infos; keys are AGSLayerContent objectIdentifier values
    private var legendInfos = [UInt: [AGSLegendInfo]]()
    
    // dictionary of symbol swatches (images); keys are the symbol used to create the swatch
    private var symbolSwatches = [AGSSymbol: UIImage]()
    
    // the array of all layers in the map, including basemap layers
    private var layerArray = [AGSLayer]()
    
    // the array of legend items; this is used to populate the tableView
    private var legendArray = [AnyObject]()
    
    // these are used when calling tableView.dequeueReusableCell
    private static let legendInfoCellID: String = "LegendInfo"
    private static let layerTitleCellID: String = "LayerTitle"
    private static let sublayerTitleCellID: String = "SublayerTitle"
    
    // tags of cell subviews
    private static let labelTag: Int = 1
    private static let imageViewTag: Int = 2
    private static let activityIndicatorTag: Int = 3
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("use the method `makeLegendViewController` instead")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // use this static method to instantiate the view controller from our storyboard
    public static func makeLegendViewController(geoView: AGSGeoView? = nil) -> LegendViewController? {
        // get the bundle and then the storyboard
        let storyboard = UIStoryboard(name: "Legend", bundle: .module)
        
        // create the legend VC from the storyboard
        let legendVC = storyboard.instantiateInitialViewController() as? LegendViewController
        legendVC?.geoView = geoView
        
        return legendVC
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return legendArray.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        // configure the cell...
        let rowItem: AnyObject = legendArray[indexPath.row]
        if let layer = rowItem as? AGSLayer {
            // item is a layer
            cell = tableView.dequeueReusableCell(withIdentifier: LegendViewController.layerTitleCellID)!
            let textLabel = cell.viewWithTag(LegendViewController.labelTag) as? UILabel
            textLabel?.text = layer.name
        } else if let layerContent = rowItem as? AGSLayerContent {
            // item is not a layer, but still implements AGSLayerContent
            // so it's a sublayer
            cell = tableView.dequeueReusableCell(withIdentifier: LegendViewController.sublayerTitleCellID)!
            let textLabel = cell.viewWithTag(LegendViewController.labelTag) as? UILabel
            textLabel?.text = layerContent.name
        } else if let legendInfo = rowItem as? AGSLegendInfo {
            // item is a legendInfo
            cell = tableView.dequeueReusableCell(withIdentifier: LegendViewController.legendInfoCellID)!
            let textLabel = cell.viewWithTag(LegendViewController.labelTag) as? UILabel
            textLabel?.text = legendInfo.name
            
            let imageview = cell.viewWithTag(LegendViewController.imageViewTag) as? UIImageView
            if let symbol = legendInfo.symbol {
                let activityIndicator = cell.viewWithTag(LegendViewController.activityIndicatorTag) as! UIActivityIndicatorView

                if let swatch = self.symbolSwatches[symbol] {
                    // we have a swatch, so set it into the imageView and stop the activity indicator
                    imageview?.image = swatch
                    activityIndicator.stopAnimating()
                } else {
                    // tag the cell so we know what index path it's being used for
                    cell.tag = indexPath.hashValue

                    // we don't have a swatch for the given symbol, start the activity indicator
                    // and create the swatch
                    activityIndicator.startAnimating()
                    symbol.createSwatch(completion: { [weak self] (image, _) -> Void in
                        // make sure this is the cell we still care about and that it
                        // wasn't already recycled by the time we get the swatch
                        if cell.tag != indexPath.hashValue {
                            return
                        }

                        // set the swatch into our dictionary and reload the row
                        self?.symbolSwatches[symbol] = image
                        tableView.reloadRows(at: [indexPath], with: .automatic)
                    })
                }
            }
        }

        return cell
    }

    // MARK: - Layer Loading
    
    // update the legend data for all layers and sublayers
    private func updateLayerData() {
        // remove all saved data
        legendInfos.removeAll()
        symbolSwatches.removeAll()
        legendArray.removeAll()
        
        populateLayerArray()
    }
    
    // Populates the "layerArray", the array of all available layers,
    // then loads all of the layers and sublayers.
    private func populateLayerArray() {
        layerArray.removeAll()
        
        var basemap: AGSBasemap?
        
        // Because the layers in the map's operationalLayers property
        // are drawn from the bottom up (the first layer in the array is
        // at the bottom), the initial order is essentially reversed from
        // how we want to display the legend.  Hence the "reversedLayerArray".
        var reversedLayerArray = [AGSLayer]()
        if let mapView = geoView as? AGSMapView {
            basemap = mapView.map?.basemap
            if let layers = mapView.map?.operationalLayers as AnyObject as? [AGSLayer] {
                reversedLayerArray.append(contentsOf: layers)
            }
        } else if let sceneView = geoView as? AGSSceneView {
            basemap = sceneView.scene?.basemap
            if let layers = sceneView.scene?.operationalLayers as AnyObject as? [AGSLayer] {
                reversedLayerArray.append(contentsOf: layers)
            }
        }
        
        // check if we have a basemap
        if  let basemap = basemap {
            // Append any reference layers at the end of the list
            // so when they're reversed, they are at the top.
            if let referenceLayers = basemap.referenceLayers as AnyObject as? [AGSLayer] {
                reversedLayerArray.append(contentsOf: referenceLayers)
            }

            // Insert any base layers at the beginning of the list
            // so when they are reversed, they're at the bottom.
            if let baseLayers = basemap.baseLayers as AnyObject as? [AGSLayer] {
                reversedLayerArray.insert(contentsOf: baseLayers, at: 0)
            }
        }
        
        // filter any layers which are not visible or not showInLegend
        reversedLayerArray = reversedLayerArray.filter { $0.isVisible && $0.showInLegend }
        
        // This is "!reverseLayerOrder" because the layers are by default reversed
        // and will only NOT be reversed here if reverseLayerOrder == true.
        if !reverseLayerOrder && !reversedLayerArray.isEmpty {
            layerArray.append(contentsOf: reversedLayerArray.reversed())
        } else {
            // we are reversing the order, so just use the original reversedLayerArray
            layerArray.append(contentsOf: reversedLayerArray)
        }

        // now make sure all the layers are loaded
        loadLayers()
    }
    
    // load layers from layer array
    private func loadLayers() {
        layerArray.forEach { self.loadIndividualLayer($0) }
    }
    
    // load an individual layer as AGSLayerContent
    private func loadIndividualLayer(_ layerContent: AGSLayerContent) {
        if let layer = layerContent as? AGSLayer {
            // we have an AGSLayer, so make sure it's loaded
            layer.load { [weak self] (_) in
                self?.loadSublayersOrLegendInfos(layerContent)
            }
        } else {
            self.loadSublayersOrLegendInfos(layerContent)
        }
    }
    
    private func loadSublayersOrLegendInfos(_ layerContent: AGSLayerContent) {
        // This is the deepest level we can go and we're assured that
        // the AGSLayer is loaded for this layer/sublayer, so
        // set the contents changed handler.
        layerContent.subLayerContentsChangedHandler = { [weak self] () in
            DispatchQueue.main.async {
                self?.updateLegendArray()
            }
        }

        // if we have sublayer contents, load those as well
        if !layerContent.subLayerContents.isEmpty {
            layerContent.subLayerContents.forEach { self.loadIndividualLayer($0) }
        } else {
            // fetch the legend infos
            layerContent.fetchLegendInfos { [weak self] (legendInfos, _) in
                // handle legendInfos
                self?.legendInfos[LegendViewController.objectIdentifierFor(layerContent)] = legendInfos
                self?.updateLegendArray()
            }
        }
    }
    
    // Because of the loading mechanism and the fact that we need to store
    // our legend data in dictionaries, we need to update the array of legend
    // items once layers load.  Updating everything here will make
    // implementing the table view data source methods much easier.
    private func updateLegendArray() {
        legendArray.removeAll()
        
        // filter any layers which are not visible or not showInLegend
        let legendLayers = layerArray.filter { $0.isVisible && $0.showInLegend }
        legendLayers.forEach { (layerContent) in
            var showAtScale = true
            if respectScaleRange {
                // if we're respecting the scale range, make sure our layerContent is in scale
                if let viewpoint = geoView?.currentViewpoint(with: .centerAndScale) {
                    if !viewpoint.targetScale.isNaN {
                        // if targetScale is not NAN (i.e., is valid...)
                        showAtScale = layerContent.isVisible(atScale: viewpoint.targetScale)
                    }
                }
            }
            
            // if we're showing the layerContent, add it to our legend array
            if showAtScale {
                if let featureCollectionLayer = layerContent as? AGSFeatureCollectionLayer {
                    // only show Feature Collection layer if the sublayer count is > 1
                    // but always show the sublayers (the call to `updateLayerLegend`)
                    if featureCollectionLayer.layers.count > 1 {
                        legendArray.append(layerContent)
                    }
                } else {
                    legendArray.append(layerContent)
                }
                updateLayerLegend(layerContent)
            }
        }

        tableView?.reloadData()
    }
    
    // Handle subLayerContents and legend infos; this method assumes that
    // the incoming layerContent argument is visible and showInLegend == true.
    private func updateLayerLegend(_ layerContent: AGSLayerContent) {
        if !layerContent.subLayerContents.isEmpty {
            // filter any sublayers which are not visible or not showInLegend
            let sublayerContents = layerContent.subLayerContents.filter { $0.isVisible && $0.showInLegend }
            sublayerContents.forEach { (layerContent) in
                legendArray.append(layerContent)
                updateLayerLegend(layerContent)
            }
        } else {
            if let internalLegendInfos: [AGSLegendInfo] = legendInfos[LegendViewController.objectIdentifierFor(layerContent as AnyObject)] {
                legendArray += internalLegendInfos
            }
        }
    }
    
    // MARK: - Utility
    
    // Returns a unique UINT for each object. Used because AGSLayerContent is not hashable
    // and we need to use it as the key in our dictionary of legendInfo arrays.
    private static func objectIdentifierFor(_ obj: AnyObject) -> UInt {
        return UInt(bitPattern: ObjectIdentifier(obj))
    }
}

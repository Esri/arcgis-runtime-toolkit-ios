// Copyright 2016 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS

/// An object that encapsulates information related to a feature template
public class FeatureTemplateInfo{
    /// The feature layer that the template is from
    public let featureLayer: AGSFeatureLayer
    /// The feature table that the template is from
    public let featureTable: AGSArcGISFeatureTable
    /// The feature template
    public let featureTemplate: AGSFeatureTemplate
    /// The swatch for the feature template
    public var swatch: UIImage?
    
    fileprivate init(featureLayer: AGSFeatureLayer, featureTable: AGSArcGISFeatureTable, featureTemplate: AGSFeatureTemplate, swatch: UIImage? = nil){
        self.featureLayer = featureLayer
        self.featureTable = featureTable
        self.featureTemplate = featureTemplate
        self.swatch = swatch
    }
}

/// The protocol you implement to respond as the user interacts with the feature templates
/// view controller.
public protocol TemplatePickerViewControllerDelegate: AnyObject {
    /// Tells the delegate that the user has cancelled selecting a template.
    ///
    /// - Parameter templatePickerViewController: The current template picker view controller.
    func templatePickerViewControllerDidCancel(_ templatePickerViewController: TemplatePickerViewController)
    /// Tells the delegate that the user has selected a feature template.
    ///
    /// - Parameters:
    ///   - templatePickerViewController: The current template picker view controller.
    ///   - featureTemplateInfo: The selected feature template.
    func templatePickerViewController(_ templatePickerViewController: TemplatePickerViewController, didSelect featureTemplateInfo: FeatureTemplateInfo)
}

/// A view controller that is useful for showing the user a list of feature templates
/// and allowing them to choose one.
/// This view controller is meant to be embedded in a navigation controller.
public class TemplatePickerViewController: TableViewController {
    
    /// The map which this view controller will display the feature templates from
    public private(set) var map: AGSMap?
    
    private var tables = [AGSArcGISFeatureTable]()
    private var currentDatasource = [String: [FeatureTemplateInfo]]()
    private var isFiltering: Bool = false
    private var unfilteredInfos = [FeatureTemplateInfo]()
    private var currentInfos = [FeatureTemplateInfo](){
        didSet{
            tables = Set(self.currentInfos.map { $0.featureTable }).sorted(by: {$0.tableName < $1.tableName})
            currentDatasource = Dictionary(grouping: currentInfos, by: { $0.featureTable.tableName })
            self.tableView.reloadData()
        }
    }
    
    /// Initializes a `TemplatePickerViewController` with a map.
    public init(map: AGSMap){
        super.init(nibName: nil, bundle: nil)
        self.map = map
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The delegate that will handle the selection and cancelation of the `TemplatePickerViewController`.
    public weak var delegate: TemplatePickerViewControllerDelegate?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        definesPresentationContext = true
        
        // create a search controller
        navigationItem.searchController = makeSearchController()
        
        // add cancel button
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(TemplatePickerViewController.cancelAction))
        
        // load map, get initial data
        self.map?.load(){ [weak self] error in

            guard let self = self else{
                return
            }
            
            guard let map = self.map else{
                return
            }
            
            if error == nil{
                self.getTemplates(map: map)
            }
        }
    }
    
    private func makeSearchController() -> UISearchController {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchResultsUpdater = self
        
        let searchBar = searchController.searchBar
        searchBar.spellCheckingType = .no
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        
        return searchController
    }
    
    /// Gets the templates out of a map.
    /// This should only be called once the map is loaded.
    private func getTemplates(map: AGSMap){
        
        // get the templates for the map, this function should be called once the map is loaded
        
        // go through each layer and if it has a popup definition, editable and can create features
        // then add it's info to the list
        for layer in map.operationalLayers as! [AGSLayer]{
            
            guard let fl = layer as? AGSFeatureLayer, fl.featureTable is AGSArcGISFeatureTable else {
                continue
            }
            
            fl.load{ [weak self] error in
                guard error == nil else{
                    return
                }
                
                self?.getTemplates(featureLayer: fl)
            }
            
        }
        
    }
    
    /// Gets the templates out of a feature layer and associated table.
    /// This should only be called once the feature layer is loaded.
    private func getTemplates(featureLayer: AGSFeatureLayer){
        
        guard let table = featureLayer.featureTable as? AGSArcGISFeatureTable else{
            return
        }
        
        guard let popupDef = featureLayer.popupDefinition, popupDef.allowEdit || table.canAddFeature else{
            return
        }
        
        let tableTemplates = table.featureTemplates.map({
            FeatureTemplateInfo(featureLayer:featureLayer, featureTable:table, featureTemplate:$0)
        })
        
        let typeTemplates = table.featureTypes
            .lazy
            .flatMap({ $0.templates })
            .map({ FeatureTemplateInfo(featureLayer:featureLayer, featureTable:table, featureTemplate:$0) })
        
        let infos = tableTemplates + typeTemplates
        
        // add to list of unfiltered infos
        unfilteredInfos.append(contentsOf: infos)
        
        // re-assign to the current infos so we can update the tableview
        // only should do this if not currently filtering
        if !isFiltering{
            currentInfos = unfilteredInfos
        }
        
        // generate swatches for the layer infos
        for index in infos.indices{
            let info = infos[index]
            if let feature = info.featureTable.createFeature(with: info.featureTemplate){
                let sym = info.featureLayer.renderer?.symbol(for: feature)
                sym?.createSwatch{ [weak self] image, error in
                    
                    guard error == nil else{
                        return
                    }
                    
                    // update info with swatch
                    infos[index].swatch = image
                    
                    // reload index where that info currently is
                    if let indexPath = self?.indexPath(for: info){
                        self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
            }
        }
    }
    
    // MARK: TableView delegate/datasource methods
    
    public func numberOfSectionsInTableView(_ tableView: UITableView) -> Int{
        return tables.count
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tables[section].tableName
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // when the user taps on a feature type
        
        // first get the selected object
        let selectedFeatureTemplateInfo = infoForIndexPath(indexPath)
        
        // If the search controller is still active, the delegate will not be
        // able to dismiss us, if desired.
        // Note: we can't do this before the above, or else the object we pull
        // out of the datasource will be incorrect
        navigationItem.searchController?.isActive = false
        
        delegate?.templatePickerViewController(self, didSelect: selectedFeatureTemplateInfo)
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let tableName = tables[section].tableName
        let infos = self.currentDatasource[tableName]
        return infos?.count ?? 0
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let info = infoForIndexPath(indexPath)
        cell.textLabel?.text = info.featureTemplate.name
        cell.imageView?.image = info.swatch
        return cell
    }
    
    // MARK: go back, cancel methods
    
    @objc private func cancelAction(){
        // If the search controller is still active, the delegate will not be
        // able to dismiss us, if desired.
        navigationItem.searchController?.isActive = false
        delegate?.templatePickerViewControllerDidCancel(self)
    }
    
    // MARK: IndexPath -> Info
    
    private func infoForIndexPath(_ indexPath: IndexPath) -> FeatureTemplateInfo{
        let tableName = tables[indexPath.section].tableName
        let infos = self.currentDatasource[tableName]!
        return infos[indexPath.row]
    }
    
    private func indexPath(for info: FeatureTemplateInfo) -> IndexPath{
        
        let tableIndex = tables.index { $0.tableName == info.featureTable.tableName }!
        let infos = self.currentDatasource[info.featureTable.tableName]!
        let infoIndex = infos.index { $0 === info }!
        
        return IndexPath(row: infoIndex, section: tableIndex)
    }
}

extension TemplatePickerViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces),
            !text.isEmpty {
            isFiltering = true
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async { [weak self] in
                guard let self = self else { return }
                let filtered = self.unfilteredInfos.filter{
                    $0.featureTemplate.name.range(of: text, options: .caseInsensitive) != nil
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Make sure we are still filtering
                    if self.isFiltering{
                        self.currentInfos = filtered
                    }
                }
            }
        }
        else {
            isFiltering = false
            self.currentInfos = self.unfilteredInfos
        }
    }
}

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

public class FeatureTemplateInfo{
    public let featureLayer : AGSFeatureLayer
    public let featureTable : AGSArcGISFeatureTable
    public let featureTemplate : AGSFeatureTemplate
    public var swatch : UIImage?
    
    fileprivate init(featureLayer: AGSFeatureLayer, featureTable: AGSArcGISFeatureTable, featureTemplate: AGSFeatureTemplate, swatch: UIImage?){
        self.featureLayer = featureLayer
        self.featureTable = featureTable
        self.featureTemplate = featureTemplate
        self.swatch = swatch
    }
}

/// The protocol you implement to respond as the user interacts with the feature templates
/// view controller.
public protocol TemplatePickerViewControllerDelegate: class {
    /// Tells the delegate that the user has cancelled selecting a template.
    ///
    /// - Parameter templatePickerViewController: The current template picker view controller.
    func templatePickerViewControllerDidCancel(_ templatePickerViewController: TemplatePickerViewController)
    /// Tells the delegate that the user has selected a feature template.
    ///
    /// - Parameters:
    ///   - templatePickerViewController: The current template picker view controller.
    ///   - featureTemplateInfo: The selected feature template.
    func templatePickerViewControllerDidSelectTemplate(_ templatePickerViewController: TemplatePickerViewController, featureTemplateInfo: FeatureTemplateInfo)
}

public class TemplatePickerViewController: TableViewController, UINavigationBarDelegate {
    
    public private(set) var map : AGSMap?
    
    private var tables = [AGSArcGISFeatureTable]()
    private var currentDatasource = [String: [FeatureTemplateInfo]]()
    private var isFiltering : Bool = false
    private var unfilteredInfos = [FeatureTemplateInfo]()
    private var currentInfos = [FeatureTemplateInfo](){
        didSet{
            tables = Set(self.currentInfos.map { $0.featureTable }).sorted(by: {$0.tableName < $1.tableName})
            currentDatasource = [String: [FeatureTemplateInfo]]()
            currentInfos.forEach{
                var infosForTable = currentDatasource[$0.featureTable.tableName] ?? [FeatureTemplateInfo]()
                infosForTable.append($0)
                currentDatasource[$0.featureTable.tableName] = infosForTable
            }
            self.tableView.reloadData()
        }
    }
    
    public init(map: AGSMap){
        super.init(nibName: nil, bundle: nil)
        self.map = map
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public weak var delegate : TemplatePickerViewControllerDelegate?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        definesPresentationContext = true
        
        // create a search controller
        navigationItem.searchController = makeSearchController()
        
        // add cancel button
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(TemplatePickerViewController.cancelAction))
        
        // load map, get initial data
        self.map?.load(){ [weak self] error in
            
            guard let map = self?.map else{
                return
            }
            
            if error == nil{
                self?.getInitialData(map: map)
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
    
    private func getInitialData(map: AGSMap){
        
        // get the initial data for the map, this function should be called once the map is loaded
        
        guard let map = self.map else{
            return
        }
        
        // go through each layer and if it has a popup definition, editable and can create features
        // then add it's info to the list
        for layer in map.operationalLayers as NSArray as! [AGSLayer]{
            
            guard let fl = layer as? AGSFeatureLayer, let table = fl.featureTable as? AGSArcGISFeatureTable else {
                continue
            }
            
            fl.load{ [weak self] error in
                
                if error != nil{
                    return
                }
                
                guard let strongSelf = self else{
                    return
                }
                
                guard let popupDef = fl.popupDefinition, popupDef.allowEdit || table.canAddFeature else{
                    return
                }
                
                let tableTemplates = table.featureTemplates.map({
                    FeatureTemplateInfo(featureLayer:fl, featureTable:table, featureTemplate:$0, swatch:nil)
                })
                
                let typeTemplates = table.featureTypes
                    .flatMap({ $0.templates })
                    .map({ FeatureTemplateInfo(featureLayer:fl, featureTable:table, featureTemplate:$0, swatch:nil) })
                
                let infos = tableTemplates + typeTemplates
                
                // add to list of unfiltered infos
                strongSelf.unfilteredInfos.append(contentsOf: infos)
                
                // re-assign to the current infos so we can update the tableview
                // only should do this if not currently filtering
                if !strongSelf.isFiltering{
                    strongSelf.currentInfos = strongSelf.unfilteredInfos
                }
                
                // generate swatches for the layer infos
                for (index, info) in infos.enumerated(){
                    if let feature = info.featureTable.createFeature(with: info.featureTemplate){
                        let sym = info.featureLayer.renderer?.symbol(for: feature)
                        sym?.createSwatch{ image, error in
                            
                            if error != nil{
                                return
                            }
                            
                            // update info with swatch
                            infos[index].swatch = image
                            
                            // reload index where that info currently is
                            if let index = strongSelf.indexPathForInfo(info){
                                strongSelf.tableView.reloadRows(at: [index], with: .automatic)
                            }
                        }
                    }
                }
            }
            
        }
        
    }
    
    // MARK: NavBar delegate
    
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
    
    // MARK: TableView delegate/datasource methods
    
    public func numberOfSectionsInTableView(_ tableView: UITableView) -> Int{
        return tables.count
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tables.count == 0 ? nil : tables[section].tableName
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // when the user taps on a feature type
        
        // first get the selected object
        let selectedFeatureTemplateInfo = infoForIndexPath(indexPath)!
        
        // If the search controller is still active, the delegate will not be
        // able to dismiss us, if desired.
        // Note: we can't do this before the above, or else the object we pull
        // out of the datasource will be incorrect
        navigationItem.searchController?.isActive = false
        
        delegate?.templatePickerViewControllerDidSelectTemplate(self, featureTemplateInfo: selectedFeatureTemplateInfo)
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard tables.count > 0 else {
            return 0
        }
        
        let tableName = tables[section].tableName
        let infos = self.currentDatasource[tableName]
        return infos?.count ?? 0
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let info = infoForIndexPath(indexPath)!
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
    
    private func infoForIndexPath(_ indexPath: IndexPath) -> FeatureTemplateInfo?{
        let tableName = tables[indexPath.section].tableName
        let infos = self.currentDatasource[tableName]
        return infos?[indexPath.row]
    }
    
    private func indexPathForInfo(_ info: FeatureTemplateInfo) -> IndexPath?{
        
        let tableIndex = tables.index { $0.tableName == info.featureTable.tableName }
        let infos = self.currentDatasource[info.featureTable.tableName]
        let infoIndex = infos?.index { $0 === info }
        
        guard let section = tableIndex, let row = infoIndex else{
            return nil
        }
        
        return IndexPath(row: row, section: section)
    }
}

extension TemplatePickerViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces),
            !text.isEmpty {
            isFiltering = true
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                let filtered = self.unfilteredInfos.filter{
                    $0.featureTemplate.name.range(of: text, options: .caseInsensitive) != nil
                }
                DispatchQueue.main.async {
                    self.currentInfos = filtered
                }
            }
        }
        else {
            isFiltering = false
            self.currentInfos = self.unfilteredInfos
        }
    }
}

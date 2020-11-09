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
public class FeatureTemplateInfo {
    /// The feature layer that the template is from
    public let featureLayer: AGSFeatureLayer
    /// The feature table that the template is from
    public let featureTable: AGSArcGISFeatureTable
    /// The feature template
    public let featureTemplate: AGSFeatureTemplate
    /// The swatch for the feature template
    public var swatch: UIImage?
    
    fileprivate init(featureLayer: AGSFeatureLayer, featureTable: AGSArcGISFeatureTable, featureTemplate: AGSFeatureTemplate, swatch: UIImage? = nil) {
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
    public let map: AGSMap?
    
    private var tables = [AGSArcGISFeatureTable]()
    private var currentDatasource = [String: [FeatureTemplateInfo]]()
    private var isFiltering: Bool = false
    private var unfilteredInfos = [FeatureTemplateInfo]()
    private var currentInfos = [FeatureTemplateInfo]() {
        didSet {
            tables = Set(self.currentInfos.map { $0.featureTable }).sorted { $0.tableName < $1.tableName }
            currentDatasource = Dictionary(grouping: currentInfos) { $0.featureTable.tableName }
            self.tableView.reloadData()
        }
    }
    
    /// Initializes a `TemplatePickerViewController` with a map.
    public init(map: AGSMap) {
        self.map = map
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
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
        
        // get the templates from the map and load them as the datasource
        if let map = map {
            getTemplateInfos(map: map, completion: loadInfosAndCreateSwatches)
        }
    }
    
    private func makeSearchController() -> UISearchController {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchResultsUpdater = self
        
        let searchBar = searchController.searchBar
        searchBar.spellCheckingType = .no
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        
        return searchController
    }
    
    /// Gets the templates out of a map.
    private func getTemplateInfos(map: AGSMap, completion: @escaping (([FeatureTemplateInfo]) -> Void) ) {
        map.load { [weak self] error in
            guard let self = self else { return }
            guard error == nil else { return }
            
            let allLayers: [AGSLayer] = (map.operationalLayers as Array + map.basemap.baseLayers as Array + map.basemap.referenceLayers as Array) as! [AGSLayer]
            
            let featureLayers = allLayers
                .compactMap { $0 as? AGSFeatureLayer }
                .filter { $0.featureTable is AGSArcGISFeatureTable }
            
            AGSLoadObjects(featureLayers) { [weak self] _ in
                guard let self = self else { return }
                let templates = featureLayers.flatMap { return self.getTemplateInfos(featureLayer: $0) }
                completion(templates)
            }
        }
    }
    
    /// Gets the templates out of a feature layer and associated table.
    /// This should only be called once the feature layer is loaded.
    private func getTemplateInfos(featureLayer: AGSFeatureLayer) -> [FeatureTemplateInfo] {
        guard let table = featureLayer.featureTable as? AGSArcGISFeatureTable else {
            return []
        }
        
        guard let popupDef = featureLayer.popupDefinition, popupDef.allowEdit || table.canAddFeature else {
            return []
        }
        
        let tableTemplates = table.featureTemplates.map {
            FeatureTemplateInfo(featureLayer: featureLayer, featureTable: table, featureTemplate: $0)
        }
        
        let typeTemplates = table.featureTypes
            .lazy
            .flatMap { $0.templates }
            .map { FeatureTemplateInfo(featureLayer: featureLayer, featureTable: table, featureTemplate: $0) }
        
        return tableTemplates + typeTemplates
    }
    
    /// Loads the template infos as the current datasource
    /// and creates swatches for them
    private func loadInfosAndCreateSwatches(infos: [FeatureTemplateInfo]) {
        // if filtering, need to disable it
        if isFiltering {
            navigationItem.searchController?.isActive = false
        }
        
        // add to list of unfiltered infos
        unfilteredInfos = infos
        
        // re-assign to the current infos so we can update the tableview
        currentInfos = unfilteredInfos
        
        // generate swatches for the layer infos
        for index in infos.indices {
            let info = infos[index]
            if let feature = info.featureTable.createFeature(with: info.featureTemplate) {
                let sym = info.featureLayer.renderer?.symbol(for: feature)
                sym?.createSwatch { [weak self] image, error in
                    guard let self = self else { return }
                    guard error == nil else { return }
                    
                    // update info with swatch
                    infos[index].swatch = image
                    
                    let indexPath = self.indexPath(for: info)
                    
                    // Make sure the new indexPath is valid before reloading the row.
                    if indexPath.section < self.tableView.numberOfSections,
                       indexPath.row < self.tableView.numberOfRows(inSection: indexPath.section) {
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
            }
        }
    }
    
    // MARK: TableView delegate/datasource methods
    
    public func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
        return tables.count
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !tables.isEmpty else { return nil }
        return tables[section].tableName
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // when the user taps on a feature type
        
        // first get the selected object
        let selectedFeatureTemplateInfo = info(for: indexPath)
        
        // Note: we can't do this before the above, or else the object we pull
        // out of the datasource will be incorrect
        //
        // If the search controller is still active, the delegate will not be
        // able to dismiss this if they showed this modally
        // (or wrapped it in a navigation controller and showed that modally)
        // Only do this if not being presented from a nav controller
        // as in that case, it causes problems when the delegate that pushed this VC
        // tries to pop it off the stack.
        if presentingViewController != nil {
            navigationItem.searchController?.isActive = false
        }
        
        delegate?.templatePickerViewController(self, didSelect: selectedFeatureTemplateInfo)
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !tables.isEmpty else { return 0 }
        let tableName = tables[section].tableName
        return currentDatasource[tableName, default: []].count
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let infoObject = info(for: indexPath)
        cell.textLabel?.text = infoObject.featureTemplate.name
        cell.imageView?.image = infoObject.swatch
        return cell
    }
    
    // MARK: go back, cancel methods
    
    @objc
    private func cancelAction() {
        // If the search controller is still active, the delegate will not be
        // able to dismiss this if they showed this modally.
        // (or wrapped it in a navigation controller and showed that modally)
        // Only do this if not being presented from a nav controller
        // as in that case, it causes problems when the delegate that pushed this VC
        // tries to pop it off the stack.
        if presentingViewController != nil {
            navigationItem.searchController?.isActive = false
        }
        delegate?.templatePickerViewControllerDidCancel(self)
    }
    
    // MARK: IndexPath -> Info
    
    private func info(for indexPath: IndexPath) -> FeatureTemplateInfo {
        let tableName = tables[indexPath.section].tableName
        let infos = self.currentDatasource[tableName]!
        return infos[indexPath.row]
    }
    
    private func indexPath(for info: FeatureTemplateInfo) -> IndexPath {
        let tableIndex = tables.firstIndex { $0.tableName == info.featureTable.tableName }!
        let infos = self.currentDatasource[info.featureTable.tableName]!
        let infoIndex = infos.firstIndex { $0 === info }!
        
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
                let filtered = self.unfilteredInfos.filter {
                    $0.featureTemplate.name.range(of: text, options: .caseInsensitive) != nil
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Make sure we are still filtering
                    if self.isFiltering {
                        self.currentInfos = filtered
                    }
                }
            }
        } else {
            isFiltering = false
            self.currentInfos = self.unfilteredInfos
        }
    }
}

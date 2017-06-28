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

import ArcGIS

public enum UnitType {
    case linear
    case area
    case angular
}

public class UnitsViewController: TableViewController, UINavigationBarDelegate, UISearchBarDelegate {
    
    public var linearUnits = [AGSLinearUnit](){
        didSet{
            // update our unfilteredUnits if we are currently looking at this unit type
            if unitType == .linear{
                unfilteredUnits = linearUnits
            }
        }
    }
    
    public var areaUnits = [AGSAreaUnit](){
        didSet{
            // update our unfilteredUnits if we are currently looking at this unit type
            if unitType == .area{
                unfilteredUnits = areaUnits
            }
        }
    }
    
    public var angularUnits = [AGSAngularUnit](){
        didSet{
            // update our unfilteredUnits if we are currently looking at this unit type
            if unitType == .angular{
                unfilteredUnits = angularUnits
            }
        }
    }
    
    public var unitSelectedHandler : ((AGSUnit) -> Void)?
    
    public var unitType : UnitType = .linear {
        didSet{
            switch unitType {
            case .linear:
                unfilteredUnits = linearUnits
            case .area:
                unfilteredUnits = areaUnits
            case .angular:
                unfilteredUnits = angularUnits
            }
        }
    }
    
    public var selectedUnit : AGSUnit? {
        didSet{
            
            self.tableView.reloadData()
            
            if let selectedUnit = self.selectedUnit{
                unitSelectedHandler?(selectedUnit)
            }
        }
    }
    
    
    public var selectedLinearUnit: AGSLinearUnit = AGSLinearUnit.meters(){
        didSet{
            if unitType == .linear{
                // update our selectedUnit if we are currently looking at this unit type
                selectedUnit = selectedLinearUnit
            }
        }
    }
    
    public var selectedAreaUnit: AGSAreaUnit = AGSAreaUnit.squareKilometers(){
        didSet{
            if unitType == .area{
                // update our selectedUnit if we are currently looking at this unit type
                selectedUnit = selectedAreaUnit
            }
        }
    }
    
    public var selectedAngularUnit: AGSAngularUnit = AGSAngularUnit.degrees(){
        didSet{
            if unitType == .angular{
                // update our selectedUnit if we are currently looking at this unit type
                selectedUnit = selectedAngularUnit
            }
        }
    }
    
    
    private var unfilteredUnits = [AGSUnit](){
        didSet{
            currentUnits = unfilteredUnits
        }
    }
    private var currentUnits = [AGSUnit](){
        didSet{
            self.tableView.reloadData()
        }
    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)   {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        sharedInitialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    private func sharedInitialization(){
        
        let linearUnitIDs : [AGSLinearUnitID] = [.centimeters, .feet, .inches, .kilometers, .meters, .miles, .millimeters, .nauticalMiles, .yards]
        
        linearUnits = linearUnitIDs.flatMap {
            AGSLinearUnit(unitID: $0)
            }.sorted{ $0.pluralDisplayName < $1.pluralDisplayName }
        
        let areaUnitIDs : [AGSAreaUnitID] = [.acres, .hectares, .squareCentimeters, .squareDecimeters, .squareFeet, .squareKilometers, .squareMeters, .squareMillimeters, .squareMiles, .squareYards]
        
        areaUnits = areaUnitIDs.flatMap {
            AGSAreaUnit(unitID: $0)
            }.sorted{ $0.pluralDisplayName < $1.pluralDisplayName }
        
        let angularUnitIDs : [AGSAngularUnitID] = [.degrees, .grads, .minutes, .radians, .seconds]
        
        angularUnits = angularUnitIDs.flatMap {
            AGSAngularUnit(unitID: $0)
            }.sorted{ $0.pluralDisplayName < $1.pluralDisplayName }
        
        if NSLocale.current.usesMetricSystem{
            selectedLinearUnit = AGSLinearUnit.kilometers()
            selectedAreaUnit = AGSAreaUnit(unitID: AGSAreaUnitID.hectares) ?? AGSAreaUnit.squareKilometers()
        }
        else{
            selectedLinearUnit = AGSLinearUnit.miles()
            selectedAreaUnit = AGSAreaUnit(unitID: AGSAreaUnitID.acres) ?? AGSAreaUnit.squareMiles()
        }
        
        selectedAngularUnit = AGSAngularUnit.degrees()
    }
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navbar
        let navbar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 64))
        navbar.autoresizingMask = .flexibleWidth
        view.addSubview(navbar)
        navbar.delegate = self
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelAction as ()->Void))
        
        let item = UINavigationItem(title: "Units")
        item.leftBarButtonItem = cancelButton
        navbar.pushItem(item, animated: false)
        
        //
        let insets = UIEdgeInsets(top: navbar.bounds.size.height, left: 0, bottom: 0, right: 0)
        tableView.contentInset = insets
        tableView.scrollIndicatorInsets = insets
        tableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
        
        // search bar
        let searchbar = UISearchBar(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 44))
        searchbar.delegate = self
        searchbar.spellCheckingType = .no
        searchbar.autocapitalizationType = .none
        searchbar.autocorrectionType = .no
        tableView.tableHeaderView = searchbar
        
    }
    
    // MARK: SearchBar / NavBar delegates
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty{
            self.currentUnits = self.unfilteredUnits
        }
        else{
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                let filtered = self.unfilteredUnits.filter{
                    $0.pluralDisplayName.range(of: searchText, options: .caseInsensitive) != nil
                }
                DispatchQueue.main.async {
                    self.currentUnits = filtered
                }
            }
            
        }
    }
    
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
    
    // MARK: TableView delegate/datasource methods
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        // when the user taps on a unit
        //

        self.goBack{
            let unit = self.unitForIndexPath(indexPath)
            
            // store the last selected value for current unit type
            switch self.unitType {
            case .linear:
                if let sel = unit as? AGSLinearUnit{
                    self.selectedLinearUnit = sel
                }
            case .area:
                if let sel = unit as? AGSAreaUnit{
                    self.selectedAreaUnit = sel
                }
            case .angular:
                if let sel = unit as? AGSAngularUnit{
                    self.selectedAngularUnit = sel
                }
            }
        }
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentUnits.count
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let unit = unitForIndexPath(indexPath)
        if unit == selectedUnit{
            cell.accessoryType = .checkmark
        }
        else{
            cell.accessoryType = .none
        }
        cell.textLabel?.text = unit.pluralDisplayName
        return cell
    }
    
    // MARK: go back, cancel methods
    
    @objc private func cancelAction(){
        self.goBack(nil)
    }
    
    @objc private func cancelAction(_ sender: AnyObject) {
        self.goBack(nil)
    }
    
    // MARK: IndexPath -> Info
    
    private func unitForIndexPath(_ indexPath: IndexPath) -> AGSUnit{
        return currentUnits[indexPath.row]
    }
    
}




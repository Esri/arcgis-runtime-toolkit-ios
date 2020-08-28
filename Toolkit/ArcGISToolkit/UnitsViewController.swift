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
import class ArcGIS.AGSUnit

/// The protocol you implement to respond as the user interacts with the units
/// view controller.
public protocol UnitsViewControllerDelegate: AnyObject {
    /// Tells the delegate that the user has cancelled selecting a unit.
    ///
    /// - Parameter unitsViewController: The current units view controller.
    func unitsViewControllerDidCancel(_ unitsViewController: UnitsViewController)
    /// Tells the delegate that the user has selected a unit.
    ///
    /// - Parameters:
    ///   - unitsViewController: The current units view controller.
    func unitsViewControllerDidSelectUnit(_ unitsViewController: UnitsViewController)
}

/// A view controller for selecting a unit from a list of units.
public class UnitsViewController: TableViewController {
    /// The delegate of the units view controller.
    public weak var delegate: UnitsViewControllerDelegate?
    
    /// The units presented to the user.
    public var units = [AGSUnit]() {
        didSet {
            guard isViewLoaded else { return }
            tableView.reloadData()
        }
    }
    
    /// The currently selected unit.
    public var selectedUnit: AGSUnit? {
        didSet {
            guard selectedUnit != oldValue else { return }
            selectedUnitDidChange(oldValue)
        }
    }
    
    /// The units that match the search predicate or `nil` if the search field
    /// is empty.
    private var filteredUnits: [AGSUnit]? {
        didSet {
            guard filteredUnits != oldValue else { return }
            tableView.reloadData()
        }
    }
    
    /// Called in response to the Cancel button being tapped.
    @objc
    private func cancel() {
        // If the search controller is still active, the delegate will not be
        // able to dismiss this if they showed this modally.
        // (or wrapped it in a navigation controller and showed that modally)
        // Only do this if not being presented from a nav controller
        // as in that case, it causes problems when the delegate that pushed this VC
        // tries to pop it off the stack.
        if presentingViewController != nil {
            navigationItem.searchController?.isActive = false
        }
        delegate?.unitsViewControllerDidCancel(self)
    }
    
    /// Called in response to `selectedUnit` changing.
    ///
    /// - Parameter previousSelectedUnit: The previous value of `selectedUnit`.
    private func selectedUnitDidChange(_ previousSelectedUnit: AGSUnit?) {
        guard isViewLoaded else { return }
        var indexPaths = [IndexPath]()
        if let unit = previousSelectedUnit, let indexPath = indexPath(for: unit) {
            indexPaths.append(indexPath)
        }
        if let unit = selectedUnit, let indexPath = indexPath(for: unit) {
            indexPaths.append(indexPath)
        }
        guard !indexPaths.isEmpty else { return }
        tableView.reloadRows(at: indexPaths, with: .automatic)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        sharedInitialization()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    private func sharedInitialization() {
        title = "Units"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(UnitsViewController.cancel))
        definesPresentationContext = true
        navigationItem.searchController = makeSearchController()
    }
    
    /// Creates a search controller for searching the list of units.
    ///
    /// - Returns: A configured search controller.
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
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: TableView delegate/datasource methods
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // when the user taps on a unit
        //
        tableView.deselectRow(at: indexPath, animated: true)
        let unit = unitForCell(at: indexPath)
        guard unit != selectedUnit else { return }
        selectedUnit = unit
        // If the search controller is still active, the delegate will not be
        // able to dismiss this if they showed this modally.
        // (or wrapped it in a navigation controller and showed that modally)
        // Only do this if not being presented from a nav controller
        // as in that case, it causes problems when the delegate that pushed this VC
        // tries to pop it off the stack.
        if presentingViewController != nil {
            navigationItem.searchController?.isActive = false
        }
        delegate?.unitsViewControllerDidSelectUnit(self)
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredUnits?.count ?? units.count
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let unit = unitForCell(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        cell.textLabel?.text = unit.pluralDisplayName
        cell.accessoryType = unit == selectedUnit ? .checkmark : .none
        return cell
    }
    
    // MARK: IndexPath -> Info
    
    /// Returns the index path of the cell corresponding to the given unit.
    ///
    /// - Parameter unit: A unit.
    /// - Returns: An index path or `nil` if there is no cell corresponding to
    /// the given unit.
    private func indexPath(for unit: AGSUnit) -> IndexPath? {
        if let filteredUnits = filteredUnits {
            if let row = filteredUnits.firstIndex(of: unit) {
                return IndexPath(row: row, section: 0)
            } else {
                return nil
            }
        } else if let row = units.firstIndex(of: unit) {
            return IndexPath(row: row, section: 0)
        } else {
            return nil
        }
    }
    
    /// The unit for the cell at the given index path.
    ///
    /// - Parameter indexPath: An index path.
    /// - Returns: The unit corresponding to the cell at the given index path.
    private func unitForCell(at indexPath: IndexPath) -> AGSUnit {
        return filteredUnits?[indexPath.row] ?? units[indexPath.row]
    }
}

extension UnitsViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces),
            !text.isEmpty {
            filteredUnits = units.filter {
                $0.pluralDisplayName.range(of: text, options: .caseInsensitive) != nil
            }
        } else {
            filteredUnits = nil
        }
    }
}

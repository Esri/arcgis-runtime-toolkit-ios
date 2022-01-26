//
// Copyright 2021 Esri.

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
import Foundation

/// ViewController for the site and facility prompt
internal class SiteFacilityPromptViewController: UIViewController {
    var delegate: FloorFilterViewControllerDelegate?
    var viewModel = FloorFilterViewModel()
    
    /// UI Elements and constraints
    @IBOutlet weak var siteFacilitySearchBar: UISearchBar!
    @IBOutlet weak var backBtn: UIImageView!
    @IBOutlet weak var closeBtn: UIImageView!
    @IBOutlet weak var promptTitle: UILabel!
    @IBOutlet weak var promptSubtitle: UILabel!
    @IBOutlet weak var promptTitleSubtitleStackView: UIStackView!
    @IBOutlet weak var siteFacilityTableView: UITableView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var designableViewHeight: NSLayoutConstraint!
    
    private var originalYPositionForPanel: CGFloat = 0.0
    
    /// Show the facilities list directly if the map has no sites configured or if there is a previously selected facility
    private var isShowingFacilities = false
    private var isSearchActive = false
    
    /// Filtered facilities and sites list based on search query
    private var filteredSearchFacilities: [AGSFloorFacility] = []
    private var filteredSearchSites: [AGSFloorSite] = []
    
    private func getFilteredFacilities() -> [AGSFloorFacility] {
        return isSearchActive ? filteredSearchFacilities : viewModel.facilities
    }
    
    private func getFilteredSites() -> [AGSFloorSite] {
        return isSearchActive ? filteredSearchSites : viewModel.sites
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isShowingFacilities = (viewModel.sites.isEmpty || viewModel.selectedFacility != nil) ? true : false
        initializeButtonsClickListeners()
        updatePromptViewHeight()
        updatePromptTitle()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        initializeSiteFacilityTableView()
        initializeSiteFacilitySearchBar()
        initializeButtonsClickListeners()
       
        updatePromptViewHeight()
        updatePromptTitle()
    }
    
    private func initializeButtonsClickListeners() {
        closeBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.closeSiteFacilityPrompt)))
        closeBtn.isUserInteractionEnabled = true
        backBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backButtonPressed)))
        backBtn.isUserInteractionEnabled = true
    }
    
    private func updatePromptViewHeight() {
        self.designableViewHeight.constant = 380
        bottomConstraint.constant = ((UIScreen.main.bounds.height / 2) - (self.designableViewHeight.constant / 2))
        originalYPositionForPanel = bottomConstraint.constant
    }
    
    @objc func closeSiteFacilityPrompt() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func backButtonPressed() {
        isShowingFacilities = false
        siteFacilityTableView?.reloadData()
    }
    
    private func updatePromptTitle() {
        promptTitle.font = UIFont.boldSystemFont(ofSize: 17)
        promptSubtitle.isHidden = true
        promptSubtitle.text = ""
        if (isShowingFacilities) {
            // Add the subtitle when showing facilities
            promptSubtitle.isHidden = false
            promptSubtitle.text = "Select a Facility"
            promptTitle.text = "\(viewModel.selectedSite?.name ?? "")"
            backBtn.isHidden = false
        } else {
            promptTitle?.text = "\(viewModel.selectedSite?.name ?? "Select a Site")"
            backBtn?.isHidden = true
        }
    }
}

/// Extension for Search Bar functions
extension SiteFacilityPromptViewController: UISearchBarDelegate {
    private func initializeSiteFacilitySearchBar() {
        siteFacilitySearchBar.delegate = self
        resetSearchFilteredResults()
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([NSAttributedString.Key(rawValue: NSAttributedString.Key.foregroundColor.rawValue): UIColor.customBlue], for: .normal)
    }
    
    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearchActive = true
        self.siteFacilitySearchBar.showsCancelButton = true
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        isSearchActive = false
        self.siteFacilitySearchBar.resignFirstResponder()
        self.siteFacilitySearchBar.endEditing(true)
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearchActive = false
        self.siteFacilitySearchBar.text = ""
        self.siteFacilitySearchBar.resignFirstResponder()
        self.siteFacilitySearchBar.endEditing(true)
    }
    
    public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        isSearchActive = false
        self.siteFacilitySearchBar.resignFirstResponder()
        self.siteFacilitySearchBar.endEditing(true)
    }
    
    private func resetSearchFilteredResults() {
        filteredSearchSites = viewModel.sites
        filteredSearchFacilities = viewModel.facilities
    }
    
    private func dismissSearchBar() {
        self.isSearchActive = false
        self.siteFacilitySearchBar.text = ""
        self.siteFacilitySearchBar.resignFirstResponder()
        self.siteFacilitySearchBar.endEditing(true)
        self.siteFacilitySearchBar.showsCancelButton = false
    }
}

/// Extension for the Sites and Facilities Table View
extension SiteFacilityPromptViewController: UITableViewDataSource, UITableViewDelegate {
    private func initializeSiteFacilityTableView() {
        siteFacilityTableView.delegate = self
        siteFacilityTableView.dataSource = self
        siteFacilityTableView.separatorStyle = .none
        siteFacilityTableView.register(UINib(nibName: "FloorFilterSiteFacilityCell", bundle: .module), forCellReuseIdentifier: "FloorFilterSiteFacilityCell")
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        updatePromptTitle()
        return isShowingFacilities ? getFilteredFacilities().count : getFilteredSites().count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = siteFacilityTableView.dequeueReusableCell(withIdentifier: "FloorFilterSiteFacilityCell", for: indexPath) as? SiteFacilityTableViewCell {
            let sites = getFilteredSites()
            let facilities = getFilteredFacilities()
        
            // If there are no sites in the map, then directly show the facilities list
            if (sites.isEmpty) {
                isShowingFacilities = true
            }
            
            cell.siteFacilityDotImg.isHidden = true
            cell.siteFacilityNameLabel?.font = UIFont(name:"Avenir", size:16)
            
            if (isShowingFacilities) {
                if (indexPath.row <= facilities.count-1) {
                    cell.siteFacilityNameLabel.text = facilities[indexPath.row].name
                    cell.siteFacilityRightChevnron.isHidden = true
                    
                    // Highlight any previously selected Facility
                    if (cell.siteFacilityNameLabel.text == viewModel.selectedFacility?.name) {
                        cell.siteFacilityDotImg.isHidden = false
                        cell.siteFacilityNameLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
                    }
                    return cell
                }
            } else {
                if (indexPath.row <= sites.count-1) {
                    cell.siteFacilityNameLabel?.text = sites[indexPath.row].name
                    cell.siteFacilityRightChevnron.isHidden = false
                    
                    // If the user clicks on Back Button, then highlight any previously selected Site
                    if (cell.siteFacilityNameLabel.text == viewModel.selectedSite?.name) {
                        cell.siteFacilityDotImg.isHidden = false
                        cell.siteFacilityNameLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
                    }
                    return cell
                }
            }
        }
        
        return UITableViewCell()
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = siteFacilityTableView.cellForRow(at: indexPath) as? SiteFacilityTableViewCell {
            let sites = getFilteredSites()
            let facilities = getFilteredFacilities()
            
            cell.siteFacilityDotImg.isHidden = true
            cell.siteFacilityNameLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
            
            if (isShowingFacilities) {
                if (indexPath.row <= facilities.count-1) {
                    viewModel.selectedFacility = facilities[indexPath.row]
                }
                
                // When a facility is selected, reset the previously selected level
                viewModel.selectedLevel = nil
                
                // Close the prompt and zoom to the selected facility
                closeSiteFacilityPrompt()
                viewModel.zoomToSelection()
                delegate?.siteFacilityIsUpdated(viewModel: viewModel)
                
                // Reset the search bar
                resetSearchFilteredResults()
                dismissSearchBar()
            } else {
                if (indexPath.row <= sites.count-1) {
                    viewModel.selectedSite = sites[indexPath.row]
                }
                
                dismissSearchBar()
                
                // Zoom to the map to the selected site in case the user closes the prompt without selecting a facility
                viewModel.zoomToSelection()
                
                // Reload the list to show the list of facilities for the selected site
                isShowingFacilities = true
                updatePromptTitle()
                siteFacilityTableView.reloadData()
            }
        }
    }
    
    /// Filter the sites or facilities data based on the search query
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if (isShowingFacilities) {
            // If the search query is empty then set FilteredSearchFacilities to all the facilities in the data
            filteredSearchFacilities = searchText.isEmpty ? viewModel.facilities : viewModel.facilities.filter {
                    (facility: AGSFloorFacility) -> Bool in
                    return facility.name.range(of: searchText, options: .caseInsensitive, range: nil, locale: nil) != nil
            }
        } else {
            // If the search query is empty then set FilteredSearchSites to all the sites in the data
            filteredSearchSites = searchText.isEmpty ? viewModel.sites : viewModel.sites.filter {
                    (site: AGSFloorSite) -> Bool in
                    return site.name.range(of: searchText, options: .caseInsensitive, range: nil, locale: nil) != nil
            }
        }
        siteFacilityTableView.reloadData()
    }
}

//
// Copyright 2022 Esri.

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

/// ViewController for the site and facility prompt.
final class SiteFacilityPromptViewController: UIViewController {
    weak var delegate: FloorFilterViewControllerDelegate?
    var viewModel = FloorFilterViewModel()
    
    /// UI Elements and constraints
    @IBOutlet var siteFacilitySearchBar: UISearchBar!
    @IBOutlet var backBtn: UIButton!
    @IBOutlet var closeBtn: UIButton!
    @IBOutlet var promptTitle: UILabel!
    @IBOutlet var promptSubtitle: UILabel!
    @IBOutlet var promptTitleSubtitleStackView: UIStackView!
    @IBOutlet var siteFacilityTableView: UITableView!
    @IBOutlet var designableViewHeight: NSLayoutConstraint!
        
    /// Show the facilities list directly if the map has no sites configured or if there is a previously selected facility.
    private var isShowingFacilities = false
    private var isSearchActive = false
    
    /// Filtered facilities and sites list based on search query.
    private var filteredSearchFacilities: [AGSFloorFacility] = []
    private var filteredSearchSites: [AGSFloorSite] = []
    
    private func filteredFacilities() -> [AGSFloorFacility] {
        if (isSearchActive) {
            return filteredSearchFacilities
        } else {
            return viewModel.facilities
        }
    }
    
    private func filteredSites() -> [AGSFloorSite] {
        if (isSearchActive) {
            return filteredSearchSites
        } else {
            return viewModel.sites
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isShowingFacilities = (viewModel.sites.isEmpty || viewModel.selectedFacility != nil)
        initializeSiteFacilityTableView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeSiteFacilityTableView()
        initializeSiteFacilitySearchBar()
        initializeButtonsClickListeners()
       
        updatePromptTitle()
    }
    
    private func initializeButtonsClickListeners() {
        closeBtn.addTarget(self, action: #selector(closeSiteFacilityPrompt), for: .touchUpInside)
        closeBtn.isUserInteractionEnabled = true
        backBtn.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backBtn.isUserInteractionEnabled = true
    }
    
    @objc func closeSiteFacilityPrompt() {
        dismiss(animated: true)
    }
    
    @objc func backButtonTapped() {
        dismissSearchBar()
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
            promptTitle.text = viewModel.selectedSite?.name ?? ""
            backBtn.isHidden = false
        } else {
            promptTitle?.text = viewModel.selectedSite?.name ?? "Select a Site"
            backBtn?.isHidden = true
        }
    }
}

/// Extension for Search Bar functions.
extension SiteFacilityPromptViewController: UISearchBarDelegate {
    private func initializeSiteFacilitySearchBar() {
        siteFacilitySearchBar.delegate = self
        resetSearchFilteredResults()
        siteFacilitySearchBar.tintColor = .customBlue
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearchActive = true
        siteFacilitySearchBar.showsCancelButton = true
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        isSearchActive = false
        siteFacilitySearchBar.resignFirstResponder()
        siteFacilitySearchBar.endEditing(true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearchActive = false
        siteFacilitySearchBar.text = ""
        siteFacilitySearchBar.resignFirstResponder()
        siteFacilitySearchBar.endEditing(true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        isSearchActive = false
        siteFacilitySearchBar.resignFirstResponder()
        siteFacilitySearchBar.endEditing(true)
    }
    
    private func resetSearchFilteredResults() {
        filteredSearchSites = viewModel.sites
        filteredSearchFacilities = viewModel.facilities
    }
    
    private func dismissSearchBar() {
        isSearchActive = false
        siteFacilitySearchBar.text = ""
        siteFacilitySearchBar.resignFirstResponder()
        siteFacilitySearchBar.endEditing(true)
        siteFacilitySearchBar.showsCancelButton = false
    }
}

/// Extension for the Sites and Facilities Table View.
extension SiteFacilityPromptViewController: UITableViewDataSource, UITableViewDelegate {
    private func initializeSiteFacilityTableView() {
        siteFacilityTableView.delegate = self
        siteFacilityTableView.dataSource = self
        siteFacilityTableView.separatorStyle = .none
        siteFacilityTableView.register(UINib(nibName: "FloorFilterSiteFacilityCell", bundle: .module), forCellReuseIdentifier: "FloorFilterSiteFacilityCell")
        siteFacilityTableView.estimatedRowHeight = 45.0
        siteFacilityTableView.rowHeight = UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        updatePromptTitle()
        return isShowingFacilities ? filteredFacilities().count : filteredSites().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = siteFacilityTableView.dequeueReusableCell(withIdentifier: "FloorFilterSiteFacilityCell", for: indexPath) as! SiteFacilityTableViewCell
        let sites = filteredSites()
        let facilities = filteredFacilities()
        
        // If there are no sites in the map, then directly show the facilities list.
        if (sites.isEmpty) {
            isShowingFacilities = true
        }
            
        cell.siteFacilityDotImg.isHidden = true
        cell.siteFacilityNameLabel?.font = UIFont(name: "Avenir", size: 16)
            
        if (isShowingFacilities) {
            cell.siteFacilityNameLabel.text = facilities[indexPath.row].name
            cell.accessoryType = .none
                    
            // Highlight any previously selected Facility.
            if (cell.siteFacilityNameLabel.text == viewModel.selectedFacility?.name) {
                cell.siteFacilityDotImg.isHidden = false
                cell.siteFacilityNameLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
            }
        } else {
            cell.siteFacilityNameLabel?.text = sites[indexPath.row].name
            cell.accessoryType = .disclosureIndicator
                
            // If the user clicks on Back Button, then highlight any previously selected Site.
            if (cell.siteFacilityNameLabel.text == viewModel.selectedSite?.name) {
                cell.siteFacilityDotImg.isHidden = false
                cell.siteFacilityNameLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = siteFacilityTableView.cellForRow(at: indexPath) as! SiteFacilityTableViewCell
        let sites = filteredSites()
        let facilities = filteredFacilities()
            
        cell.siteFacilityDotImg.isHidden = true
        cell.siteFacilityNameLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
            
        if (isShowingFacilities) {
            viewModel.selectedFacility = facilities[indexPath.row]
                
            // When a facility is selected, reset the previously selected level.
            viewModel.selectedLevel = nil
                    
            // Close the prompt and zoom to the selected facility.
            closeSiteFacilityPrompt()
            viewModel.zoomToSelection()
            delegate?.siteFacilityIsUpdated(viewModel: viewModel)
                
            // Reset the search bar.
            resetSearchFilteredResults()
            dismissSearchBar()
        } else {
            viewModel.selectedSite = sites[indexPath.row]
            viewModel.selectedFacility = nil
            viewModel.selectedLevel = nil
                
            dismissSearchBar()
                
            // Zoom to the map to the selected site in case the user closes the prompt without selecting a facility.
            viewModel.zoomToSelection()
            delegate?.siteFacilityIsUpdated(viewModel: viewModel)
                
            // Reload the list to show the list of facilities for the selected site.
            isShowingFacilities = true
            updatePromptTitle()
            siteFacilityTableView.reloadData()
        }
    }
    
    /// Filter the sites or facilities data based on the search query.
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if (isShowingFacilities) {
            // If the search query is empty then set FilteredSearchFacilities to all the facilities in the data.
            filteredSearchFacilities = searchText.isEmpty ? viewModel.facilities : viewModel.facilities.filter {
                    (facility: AGSFloorFacility) -> Bool in
                    return facility.name.range(of: searchText, options: .caseInsensitive, range: nil, locale: nil) != nil
            }
        } else {
            // If the search query is empty then set FilteredSearchSites to all the sites in the data.
            filteredSearchSites = searchText.isEmpty ? viewModel.sites : viewModel.sites.filter {
                    (site: AGSFloorSite) -> Bool in
                    return site.name.range(of: searchText, options: .caseInsensitive, range: nil, locale: nil) != nil
            }
        }
        siteFacilityTableView.reloadData()
    }
}

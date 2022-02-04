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

protocol FloorFilterViewControllerDelegate: AnyObject {
    // Updates the Floor Filter levels list with the site and facility that were selected from the prompt.
    func siteFacilityIsUpdated(viewModel: FloorFilterViewModel)
}

/// ViewController for Floor Filter that consists of a site button, levels list and close button.
public class FloorFilterViewController: UIViewController, FloorFilterViewControllerDelegate {
    /// The direction the floor filter should expand in.
    public enum ExpansionDirection {
        /// The level list expands down from the site button.
        case down
        /// The level list expands up from the site button.
        case up
    }
    
    /// The style of the floor filter.  The default is `.up`.
    /// This is immutable and will be initialized when the FloorFilter is initialized
    public private(set) var expansionDirection: ExpansionDirection = .up
    
    /// Returns the site that is currently selected.
    /// Also allows users to pass a site that needs to be selected.
    public var selectedSite: AGSFloorSite? {
        get {
            viewModel.selectedSite
        }
        set {
            selectedFacility = nil
            selectedLevel = nil
            viewModel.selectedSite = newValue
            viewModel.zoomToSelection()
        }
    }
    
    /// Returns the facility that is currently selected.
    /// Also allows users to pass a facility that needs to be selected.
    public var selectedFacility: AGSFloorFacility? {
        get {
            viewModel.selectedFacility
        }
        set {
            selectedLevel = viewModel.defaultLevel(for: newValue)
            viewModel.selectedFacility = newValue
            viewModel.zoomToSelection()
        }
    }
 
    /// Returns the level that is currently selected.
    /// Also allows users to pass a level that needs to be selected.
    public var selectedLevel: AGSFloorLevel? {
        get {
            viewModel.selectedLevel
        }
        set {
            viewModel.selectedLevel = newValue
            viewModel.filterMapToSelectedLevel()
        }
    }
    
    /// Listener when a level is changed.
    public var onSelectedLevelChangedListener: (() -> Void)?
    
    // Variables for styling the Floor Filter View.
    
    /// Font of the level short name
    public var levelFont = UIFont(name: "Avenir", size: 14.0) {
        didSet {
            processStylingParametersUpdate()
        }
    }
    
    /// Color when a level is selected in the list
    public var selectionColor: UIColor = .selectedLevelBackground {
        didSet {
            processStylingParametersUpdate()
        }
    }
    
    /// Background color of the site button, tableview and the close button
    public var backgroundColor: UIColor = UIColor.systemGray6 {
        didSet {
            backgroundColorDidChange()
        }
    }
    
    /// Text color of the level displayed that is selected
    public var selectedTextColor: UIColor = .selectedLevelText {
        didSet {
            processStylingParametersUpdate()
        }
    }
    
    /// Text color of the level displayed when it is unselected
    public var unselectedTextColor: UIColor = UIColor.label {
        didSet {
            processStylingParametersUpdate()
        }
    }
    
    /// Size of the each of the levels button, site button and close button
    public var buttonSize: CGSize = CGSize(width: 50, height: 50) {
        didSet {
            buttonSizeDidChange()
        }
    }
    
    /// This is used to determine the amount of levels to show in the TableView
    public var maxDisplayLevels: Int = 3 {
        didSet {
            processStylingParametersUpdate()
        }
    }
    
    /// Floor Filter UI Elements and Constraints.
    @IBOutlet var floorFilterView: UIView!
    @IBOutlet var siteBtn: UIButton!
    @IBOutlet var levelsTableView: UITableView!
    @IBOutlet var closeBtn: UIButton!
    @IBOutlet var floorFilterStackView: UIStackView!
    @IBOutlet var closeBtnHeight: NSLayoutConstraint!
    @IBOutlet var siteBtnHeight: NSLayoutConstraint!
    @IBOutlet var tableViewHeight: NSLayoutConstraint!
    @IBOutlet var closeBtnWidth: NSLayoutConstraint!
    @IBOutlet var siteBtnWidth: NSLayoutConstraint!
    @IBOutlet var levelCellWidth: NSLayoutConstraint!
  
    private weak var delegate: FloorFilterViewControllerDelegate?
    private var viewModel = FloorFilterViewModel()
    
    /// State of the visibility of the Floor Filter.
    private enum FloorFilterState {
        case initiallyCollapsed
        case partiallyExpanded
        case fullyExpanded
    }
    
    private var state = FloorFilterState.initiallyCollapsed {
        didSet {
            stateDidChange()
        }
    }
    
    private var floorManager: AGSFloorManager?
    
    /// GeoView that the Floor Filter is rendered on
    /// For Version 1 only MapView (2D) is supported to render the Floor Filter.
    public var geoView: AGSGeoView? {
        didSet {
            switch geoView {
            case let mapView as AGSMapView:
                mapView.map?.load { [weak self] _ in
                    guard let self = self else { return }
                    self.viewModel.mapView = mapView
                    self.floorManager = mapView.map?.floorManager
                    self.initializeFloorManager()
                    self.state = FloorFilterState.initiallyCollapsed
                }
            default:
                break
            }
        }
    }
    
    /// Static method that will be used to initialize the Floor Filter View and attach it as a SubView.
    public static func makeFloorFilterView(
        geoView: AGSGeoView?,
        expansionDirection: ExpansionDirection = .up
    ) -> FloorFilterViewController {
        let storyboard = UIStoryboard(name: "FloorFilter", bundle: .module)
        let floorFilterVC: FloorFilterViewController = storyboard.instantiateViewController(identifier: "FloorFilter")
        floorFilterVC.expansionDirection = expansionDirection
        floorFilterVC.geoView = geoView
        
        return floorFilterVC
    }
    
    @available(*, unavailable)
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("use the method `makeFloorFilterView` instead")
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Update the views that are visibile and their heights based on the state of the Floor Filter.
        updateViewsVisibilityForState(state: state)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the UI elements and on click listeners.
        initializeSiteButton()
        initializeLevelsTableView()
        initializeButtonsClickListeners()
        buttonSizeDidChange()
        backgroundColorDidChange()
        
        // Update the views that are visibile and their heights based on the state of the Floor Filter.
        updateViewsVisibilityForState(state: state)
        
        // Adjust the constraints and order of the views in the Floor Filter if placement is on top or bottom of the sceen.
        adjustConstraintsBasedOnPlacement()
    }
    
    private func initializeFloorManager() {
        guard let floorManager = floorManager else { return }
        
        floorManager.load(completion: { error in
            if error != nil || floorManager.loadStatus != .loaded {
                return
            }
            self.initializeSiteButton()
                                        
            // Filter the map to any previously selected level.
            self.viewModel.filterMapToSelectedLevel()
            self.levelsTableView.reloadData()
        })
    }
    
    private func initializeSiteButton() {
        // Enable the site button if both the floor manager and the map is loaded.
        let emptySites = viewModel.sites.isEmpty
        let emptyFacilities = viewModel.facilities.isEmpty
        if (viewModel.floorManager != nil && (geoView as? AGSMapView)?.map?.loadStatus == .loaded && (!emptySites || !emptyFacilities)) {
            addShadow()
            siteBtn.isEnabled = true
        } else {
            siteBtn.isEnabled = false
        }
    }
    
    private func initializeButtonsClickListeners() {
        siteBtn.addTarget(self, action: #selector(showSiteFacilityPrompt(sender:)), for: .touchUpInside)
        siteBtn.isUserInteractionEnabled = true
        
        closeBtn.addTarget(self, action: #selector(collapseLevelsList(sender:)), for: .touchUpInside)
        closeBtn.isUserInteractionEnabled = true
    }
    
    private func initializeLevelsTableView() {
        levelsTableView.delegate = self
        levelsTableView.dataSource = self
    }
    
    private func buttonSizeDidChange() {
        guard isViewLoaded else { return }
        siteBtnHeight.constant = buttonSize.height
        siteBtnWidth.constant = buttonSize.width
        closeBtnWidth.constant = buttonSize.width
        levelCellWidth.constant = buttonSize.width
        // By design, the close button height will be 3/4th the size of the button size.
        closeBtnHeight.constant = buttonSize.height * 0.75
    }
    
    @objc func showSiteFacilityPrompt(sender: UIButton) {
        // Only show the prompt if there sites or facilities data
        let siteFacilityPromptVC = storyboard!.instantiateViewController(identifier: "SiteFacilityPromptVC") as! SiteFacilityPromptViewController
        siteFacilityPromptVC.modalPresentationStyle = .automatic
        present(siteFacilityPromptVC, animated: true)
        siteFacilityPromptVC.delegate = self
        siteFacilityPromptVC.viewModel = viewModel
    }
    
    @objc func collapseLevelsList(sender: UIButton) {
        state = .partiallyExpanded
        self.levelsTableView.reloadData()
    }
    
    /// Observer when the state property is changed.
    private func stateDidChange() {
        updateViewsVisibilityForState(state: state)
    }
    
    /// Updates which state of the floor filter should be state.
    private func updateViewsVisibilityForState(state: FloorFilterState) {
        addCornerRadiusBasedOnPlacement()
        
        switch state {
        case .fullyExpanded:
            closeBtn?.isHidden = false
            levelsTableView?.isHidden = false
            let levelCount = CGFloat(min(viewModel.visibleLevelsInExpandedList.count, maxDisplayLevels))
            let constant = levelCount * buttonSize.height
            tableViewHeight.constant = constant
        case .partiallyExpanded:
            closeBtn?.isHidden = true
            levelsTableView?.isHidden = false
            tableViewHeight.constant = buttonSize.height
        case .initiallyCollapsed:
            closeBtn?.isHidden = true
            levelsTableView?.isHidden = true
        }
    }
    
    func siteFacilityIsUpdated(viewModel: FloorFilterViewModel) {
        self.viewModel = viewModel
        // if no facility is selected, then set the state to initially collapsed
        if (viewModel.selectedFacility != nil) {
            state = .fullyExpanded
        } else {
            state = .initiallyCollapsed
        }
       
        self.levelsTableView.reloadData()
    }
    
    private func addShadow() {
        floorFilterView.layer.shadowColor = UIColor.gray.cgColor
        floorFilterView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        floorFilterView.layer.shadowOpacity = 0.8
    }
    
    /// Callback when a styling parameter is updated
    /// Reload the table view, site button and close button
    /// Calling stateDidChange will also reload the size
    private func processStylingParametersUpdate() {
        guard isViewLoaded else { return }
        levelsTableView.reloadData()
        stateDidChange()
        adjustConstraintsBasedOnPlacement()
    }
    
    private func backgroundColorDidChange() {
        guard isViewLoaded else { return }
        siteBtn?.backgroundColor = backgroundColor
        closeBtn?.backgroundColor = backgroundColor
    }
    
    /// Add a corner radius for the cells in the levels table.
    /// Depending on the visible state of the floor filter.
    private func setTableViewCellCornerRadius(cell: UITableViewCell) {
        if state == .fullyExpanded {
            cell.cornerRadius(usingCorners: [.allCorners], cornerRadii: .zero)
        } else {
            if (expansionDirection == .down) {
                cell.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            } else {
                cell.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            }
        }
    }
    
    /// Add a corner radius to the site and close button.
    /// Depending on the placement of the Floor Filter and the current state.
    private func addCornerRadiusBasedOnPlacement() {
        if (expansionDirection == .down) {
            switch state {
            case .fullyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                closeBtn?.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            case .partiallyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            case .initiallyCollapsed:
                siteBtn?.cornerRadius(usingCorners: .allCorners, cornerRadii: CGSize(width: 5.0, height: 5.0))
            }
        } else {
            switch state {
            case .fullyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                closeBtn?.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            case .partiallyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            case .initiallyCollapsed:
                siteBtn?.cornerRadius(usingCorners: .allCorners, cornerRadii: CGSize(width: 5.0, height: 5.0))
            }
        }
    }
    
    /// Logic to adjust the floor filter if it placed on the top or bottom of the screen.
    private func adjustConstraintsBasedOnPlacement() {
        guard let floorFilterStackView = floorFilterStackView else { return }
        addCornerRadiusBasedOnPlacement()
        
        // First remove the Close Button and Site Button from the stack and then based on placement add the Buttons.
        floorFilterStackView.removeArrangedSubview(closeBtn)
        floorFilterStackView.removeArrangedSubview(siteBtn)
        floorFilterStackView.setNeedsLayout()
        
        if (expansionDirection == .down) {
            // Place the Site Button at the top of the Floor Filter View.
            // The Levels List will be unchanged and remain as the second element on the Floor Filter view.
            // Place the Close Button at the bottom of the list.
            floorFilterStackView.insertArrangedSubview(siteBtn, at: 0)
            floorFilterStackView.insertArrangedSubview(closeBtn, at: 2)
            floorFilterStackView.setNeedsLayout()
        } else {
            // Place the Close Button at the top of the Floor Filter View.
            // The Levels List will be unchanged and remain as the second element on the Floor Filter view.
            // Place the Site Button at the bottom of the list.
            floorFilterStackView.insertArrangedSubview(closeBtn, at: 0)
            floorFilterStackView.insertArrangedSubview(siteBtn, at: 2)
            floorFilterStackView.setNeedsLayout()
        }
    }
}

extension FloorFilterViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return state == .partiallyExpanded ? 1 : viewModel.visibleLevelsInExpandedList.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "levelCell", for: indexPath)
        let levels = viewModel.visibleLevelsInExpandedList
        
        cell.textLabel?.font = levelFont
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.textAlignment = .center
        setTableViewCellCornerRadius(cell: cell)
        
        // If the Floor Filter state is fully expanded then set the title of the cell based on the levels list.
        // Otherwise set the title of cell to the selected level short name.
        if (state == .fullyExpanded) {
            cell.textLabel?.text = levels[indexPath.row].shortName
        } else {
            cell.textLabel?.text = viewModel.selectedLevel?.shortName
                ?? viewModel.defaultLevel(for: viewModel.selectedFacility)?.shortName
        }
        
        let visibleLevelVerticalOrder = levels.first(where: \.isVisible)?.verticalOrder
        if let text = cell.textLabel?.text,
           levels.contains(where: { level in
                level.verticalOrder == visibleLevelVerticalOrder && level.shortName == text
           }) {
            cell.backgroundColor = selectionColor
            cell.textLabel?.textColor = selectedTextColor
        } else {
            cell.backgroundColor = backgroundColor
            cell.textLabel?.textColor = unselectedTextColor
        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (state == .fullyExpanded) {
            viewModel.selectedLevel = viewModel.visibleLevelsInExpandedList[indexPath.row]
            if let onSelectedLevelChangedListener = onSelectedLevelChangedListener {
                onSelectedLevelChangedListener()
            }
        }
        
        // If the Floor Filter state is partially expanded, then expand the state fully
        // Do not set the selected level.
        if (state == .partiallyExpanded) {
            state = .fullyExpanded
        }
        
        viewModel.filterMapToSelectedLevel()
        levelsTableView?.reloadData()
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return buttonSize.height
    }
}

/// Extension for UIView to add corner radius
private extension UIView {
    func cornerRadius(usingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: cornerRadii)
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        self.layer.mask = maskLayer
    }
}

private extension UIColor {
    /// The default background color for selected levels.
    static let selectedLevelBackground = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.39, green: 0.46, blue: 0.5, alpha: 1.00)
        } else {
            return UIColor(red: 0.78, green: 0.92, blue: 1.00, alpha: 1.00)
        }
    }
    /// The default text color for selected levels.
    static let selectedLevelText = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.00, green: 0.56, blue: 0.9, alpha: 1.00)
        } else {
            return UIColor(red: 0.00, green: 0.28, blue: 0.45, alpha: 1.00)
        }
    }
}

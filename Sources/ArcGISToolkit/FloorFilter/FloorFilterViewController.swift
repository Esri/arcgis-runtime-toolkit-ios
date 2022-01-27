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

protocol FloorFilterViewControllerDelegate: AnyObject {
    // Updates the Floor Filter levels list with the site and facility that were selected from the prompt
    func siteFacilityIsUpdated(viewModel: FloorFilterViewModel)
}

public class FloorFilterViewController: UIViewController, FloorFilterViewControllerDelegate {
    /// The direction the floor filter should expand in.
    public enum ExpansionDirection {
        /// The level list expands down from the floor filter button.
        case down
        /// The level list expands up from the floor filter button.
        case up
    }
    
    /// The style of the floor filter.  The default is `.expandUp`.
    public var style: ExpansionDirection = .up
    
    /// Public variables and functions accessible to the developer
    private var _selectedSite: AGSFloorSite? = nil
    public var selectedSite: AGSFloorSite? {
        get {
            _selectedSite ?? viewModel.selectedSite
        }
        set {
            _selectedSite = newValue
            selectedFacility = nil
            selectedLevel = nil
            viewModel.selectedSite = newValue
            viewModel.zoomToSelection()
        }
    }
    
    private var _selectedFacility: AGSFloorFacility? = nil
    public var selectedFacility: AGSFloorFacility? {
        get {
            _selectedFacility ?? viewModel.selectedFacility
        }
        set {
            _selectedFacility = newValue
            if (_selectedFacility != nil) {
                _selectedSite = viewModel.selectedFacility?.site
            }
            selectedLevel = viewModel.getDefaultLevelForFacility(facility: newValue)
            viewModel.selectedFacility = newValue
            viewModel.zoomToSelection()
        }
    }
 
    private var _selectedLevel: AGSFloorLevel? = nil
    public var selectedLevel: AGSFloorLevel? {
        get {
            _selectedLevel ?? viewModel.selectedLevel
        }
        set {
            if (_selectedLevel != newValue) {
                _selectedLevel = newValue
            }
            if (_selectedLevel != nil) {
                let selectedLevelsFacility = viewModel.selectedLevel?.facility
                _selectedSite = selectedLevelsFacility?.site
            }
            viewModel.selectedLevel = newValue
            viewModel.filterMapToSelectedLevel()
        }
    }
    
    /// Listener when a level is changed
    public var onSelectedLevelChangedListener: (() -> Void)? = nil

    /// Refresh the view with the new map
    public func refresh(geoView: AGSGeoView?){
        self.geoView = geoView
        state = FloorFilterState.initiallyCollapsed
        updateViewsVisibilityForState(state: state)
    }
    
    /// Variables for styling the Floor Filter View
    public var fontSize: CGFloat = 14.0
    public var fontName: String = "Avenir"
    public var selectionColor: UIColor = UIColor(hexString: "#C7EAFF")
    public var backgroundColor: UIColor = UIColor.systemGray6
    public var selectedTextColor: UIColor = UIColor(hexString: "#004874")
    public var unselectedTextColor: UIColor = UIColor.label
    public var buttonSize: CGSize = CGSize(width: 50, height: 50)
    public var maxDisplayLevels: Int = 3
    
    /// Floor Filter UI Elements and Constraints
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
    
    /// Floor Filter view styles variables
    /// These are the default, but will get updated with values that are provided during initialization
    
    private var buttonHeight: CGFloat = 35
    private var buttonWidth: CGFloat = 40
    
    
    /// Stores the last row that was selected in the levels tableview
    private var lastSelectedRow: IndexPath?
    /// Store the row that is currently selected in the levels tableView
    private var currentlySelectedRow: IndexPath?
  
    private weak var delegate: FloorFilterViewControllerDelegate?
    private var viewModel = FloorFilterViewModel()
    
    /// State of the visibility of the Floor Filter
    private enum FloorFilterState {
        case initiallyCollapsed
        case partiallyExpanded
        case fullyExpanded
    }
    private var state = FloorFilterState.initiallyCollapsed
    
    private var floorManager: AGSFloorManager?
    
    /// GeoView that the Floor Filter is rendered on
    /// For Version 1 only MapView (2D) is supported to render the Floor Filter
    private var geoView: AGSGeoView? {
        didSet {
            switch geoView {
            case let mapView as AGSMapView:
                mapView.map?.load { [weak self] _ in
                    guard let self = self else { return }
                    self.viewModel.mapView = mapView
                    self.viewModel.map = mapView.map
                    self.floorManager = mapView.map?.floorManager
                    self.initializeFloorManager()
                }
            default:
                break
            }
        }
    }
    
    /// Static method that will be used to initialize the Floor Filter View and attach it as a SubView
    public static func makeFloorFilterView(
        geoView: AGSGeoView?,
        expansionDirection: ExpansionDirection = .up
    ) -> FloorFilterViewController {
        let storyboard = UIStoryboard(name: "FloorFilter", bundle: .module)
        let floorFilterVC: FloorFilterViewController = storyboard.instantiateViewController(identifier: "FloorFilter")
        floorFilterVC.style = expansionDirection
        floorFilterVC.geoView = geoView
        
        return floorFilterVC
    }
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("use the method `makeFloorFilterView` instead")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Update the views that are visibile and their heights based on the state of the Floor Filter
        updateViewsVisibilityForState(state: state)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the UI elements and on click listeners
        initializeSiteButton()
        initializeLevelsTableView()
        initializeButtonsClickListeners()
        
        // Update the views that are visibile and their heights based on the state of the Floor Filter
        updateViewsVisibilityForState(state: state)
        
        // Adjust the constraints and order of the views in the Floor Filter if placement is on top or bottom of the sceen
        adjustConstraintsBasedOnPlacement()
    }
    
    private func initializeFloorManager() {
        guard let floorManager = floorManager else { return }
        
        floorManager.load(completion: { error in
            DispatchQueue.main.async {
                if error != nil || floorManager.loadStatus != .loaded {
                    return
                }
                                        
                if (floorManager.loadStatus == .loaded) {
                    self.viewModel.reset()
                    self.viewModel.floorManager = floorManager
                    self.initializeSiteButton()
                                            
                    // Filter the map to any previously selected level
                    self.viewModel.filterMapToSelectedLevel()
                    self.levelsTableView.reloadData()
                }
            }
        })
    }
    
    private func initializeSiteButton() {
        // Disable the Site Button if the Floor Manager is not loaded yet
        if (viewModel.floorManager == nil) {
            siteBtn.backgroundColor = UIColor.systemGray3
            siteBtn.isUserInteractionEnabled = false
        } else {
            addShadow()
            siteBtn.backgroundColor = backgroundColor.withAlphaComponent(0.9)
            siteBtn.isUserInteractionEnabled = true
        }
    }
    
    private func initializeButtonsClickListeners() {
        siteBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.showSiteFacilityPrompt)))
        siteBtn.isUserInteractionEnabled = true
        
        closeBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.collapseLevelsList)))
        closeBtn.isUserInteractionEnabled = true
    }
    
    private func initializeLevelsTableView() {
        levelsTableView.delegate = self
        levelsTableView.dataSource = self
        levelsTableView.separatorStyle = .none
    }
    
    @objc func showSiteFacilityPrompt(sender: UITapGestureRecognizer) {
        let storyboard = UIStoryboard(name: "FloorFilter", bundle: .module)
        
        if let siteFacilityPromptVC = storyboard.instantiateViewController(identifier: "SiteFacilityPromptVC") as? SiteFacilityPromptViewController {
            siteFacilityPromptVC.providesPresentationContextTransitionStyle = true
            siteFacilityPromptVC.definesPresentationContext = true
            siteFacilityPromptVC.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            siteFacilityPromptVC.modalTransitionStyle = UIModalTransitionStyle.coverVertical
            
            if let topVC = UIApplication.shared.topMostViewController() {
                topVC.present(siteFacilityPromptVC, animated: true, completion: nil)
            }
            siteFacilityPromptVC.delegate = self
            siteFacilityPromptVC.viewModel = viewModel
        }
    }
    
    @objc func collapseLevelsList(sender: UITapGestureRecognizer) {
        state = .partiallyExpanded
        updateViewsVisibilityForState(state: state)
        self.levelsTableView.reloadData()
    }
    
    /// Updates which state of the floor filter should be state
    private func updateViewsVisibilityForState(state: FloorFilterState) {
        siteBtnHeight.constant = buttonSize.height
        siteBtnWidth.constant = buttonSize.width
        closeBtnWidth.constant = buttonSize.width
        levelCellWidth.constant = buttonSize.width
        closeBtn.backgroundColor = backgroundColor.withAlphaComponent(0.9)
        // by design the close button height will be 3/4th the size of the button size
        closeBtnHeight.constant = buttonSize.height * 0.75
        addCornerRadiusBasedOnPlacement()
        
        switch state {
        case .fullyExpanded:
            closeBtn?.isHidden = false
            self.levelsTableView?.isHidden = false
            let levelCount = CGFloat(min(viewModel.visibleLevelsInExpandedList.count, maxDisplayLevels))
            let constant = levelCount * buttonSize.height
            self.tableViewHeight.constant = constant
        case .partiallyExpanded:
            closeBtn?.isHidden = true
            self.levelsTableView?.isHidden = false
            siteBtnHeight.constant = buttonSize.height
            tableViewHeight.constant = buttonSize.height
        case .initiallyCollapsed:
            closeBtn?.isHidden = true
            self.levelsTableView?.isHidden = true
        }
    }
    
    func siteFacilityIsUpdated(viewModel: FloorFilterViewModel) {
        self.viewModel = viewModel
        state = .fullyExpanded
        updateViewsVisibilityForState(state: state)
        self.levelsTableView.reloadData()
    }
    
    private func addShadow() {
        floorFilterView.layer.shadowColor = UIColor.gray.cgColor
        floorFilterView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        floorFilterView.layer.shadowOpacity = 0.8
    }
    
    /// Add a corner radius for the cells in the levels table
    /// Depending on the visible state of the floor filter
    private func setTableViewCellCornerRadius(cell: UITableViewCell) {
        if state == .fullyExpanded {
            cell.cornerRadius(usingCorners: [.allCorners], cornerRadii: .zero)
            
        } else {
            if (style == .down) {
                cell.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            } else {
                cell.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
            }
        }
    }
    
    /// Add a corner radius to the site and close button
    /// Depending on the placement of the Floor Filter and the current state
    private func addCornerRadiusBasedOnPlacement() {
        if (style == .down) {
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
    
    /// Logic to adjust the floor filter if it placed on the top or bottom of the screen
    private func adjustConstraintsBasedOnPlacement() {
        guard let floorFilterStackView = floorFilterStackView else { return }
        addCornerRadiusBasedOnPlacement()
        
        // First remove the Close Button and Site Button from the stack and then based on placement add the Buttons
        floorFilterStackView.removeArrangedSubview(closeBtn)
        floorFilterStackView.removeArrangedSubview(siteBtn)
        floorFilterStackView.setNeedsLayout()
        floorFilterStackView.layoutIfNeeded()
        
        if (style == .down) {
            // Place the Site Button at the top of the Floor Filter View
            // The Levels List will be unchanged and remain as the second element on the Floor Filter view
            // Place the Close Button at the bottom of the list
            floorFilterStackView.insertArrangedSubview(siteBtn, at: 0)
            floorFilterStackView.insertArrangedSubview(closeBtn, at: 2)
            floorFilterStackView.setNeedsLayout()
        } else {
            // Place the Close Button at the top of the Floor Filter View
            // The Levels List will be unchanged and remain as the second element on the Floor Filter view
            // Place the Site Button at the bottom of the list
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
        
        // Style the cell
        if cell.heightAnchor.constraint(equalToConstant: buttonSize.height).isActive == false {
            cell.heightAnchor.constraint(equalToConstant: buttonSize.height).isActive = true
        }
        if cell.widthAnchor.constraint(equalToConstant: buttonSize.width).isActive == false {
            cell.widthAnchor.constraint(equalToConstant: buttonSize.width).isActive = true
        }
        cell.textLabel?.font = UIFont(name: fontName, size: fontSize)
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.textAlignment = .center
        setTableViewCellCornerRadius(cell: cell)
        
        // If the Floor Filter state is fully expanded then set the title of the cell based on the levels list
        // Otherwise set the title of cell to the selected level short name
        if (state == .fullyExpanded) {
            cell.textLabel?.text = levels[indexPath.row].shortName
        } else {
            cell.textLabel?.text = viewModel.selectedLevel?.shortName
                ?? viewModel.getDefaultLevelForFacility(facility: viewModel.selectedFacility)?.shortName
        }
        
        let visibleLevelVerticalOrder = levels.first { $0.isVisible }.map { $0.verticalOrder }
        let levelShortNames = levels.filter { $0.verticalOrder == visibleLevelVerticalOrder }.map { $0.shortName }
        if (levelShortNames.contains(cell.textLabel?.text ?? "")) {
            cell.backgroundColor = selectionColor
            cell.textLabel?.textColor = selectedTextColor
        } else {
            cell.backgroundColor = backgroundColor
            cell.textLabel?.textColor = unselectedTextColor
        }
       
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        lastSelectedRow = currentlySelectedRow
        currentlySelectedRow = indexPath
        
        if (state == .fullyExpanded) {
            viewModel.selectedLevel = viewModel.visibleLevelsInExpandedList[indexPath.row]
            if let onSelectedLevelChangedListener = onSelectedLevelChangedListener {
                onSelectedLevelChangedListener()
            }
        }
        
        // If the Floor Filter state is partially expanded, then expand the state fully
        // Do not set the selected level
        if (state == .partiallyExpanded) {
            state = .fullyExpanded
            updateViewsVisibilityForState(state: state)
        }
        
//        // for the very first time, the last selected row will be nil, so do not add that to the array
        guard let currentlySelectedRow = currentlySelectedRow else { return }
        var rowsToReload = [currentlySelectedRow]
        if let lastSelectedRow = lastSelectedRow {
            rowsToReload.append(lastSelectedRow)
        }
        
        viewModel.filterMapToSelectedLevel()
        levelsTableView?.reloadData()
        print("Shreya selected levels last \(lastSelectedRow) and current \(currentlySelectedRow)")
    }
    
}

/// Extensions for UIViewController to get the top most view controller of the application
extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? self
        }

        if let navigation = self as? UINavigationController {
            if navigation.visibleViewController?.isBeingDismissed ?? false {
                return navigation.visibleViewController?.presentingViewController ?? self
            }
            else {
                return navigation.visibleViewController?.topMostViewController() ?? self
            }
        }

        if let presented = self.presentedViewController {
            if presented.isBeingDismissed {
                return presented.presentingViewController ?? self
            }
            else {
                return presented.topMostViewController()
            }
        }
        return self
    }
}

extension UIApplication {
    func topMostViewController() -> UIViewController? {
        if let keyWindow = windows.first(where: { $0.isKeyWindow }) {
            return keyWindow.rootViewController?.topMostViewController()
        }
        return nil
    }
}

/// Extension for UI Color to convert a HexString to UIColor
extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
        }
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
}

/// Extension for UIView to add corner radius
extension UIView {
    func cornerRadius(usingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: cornerRadii)
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        self.layer.mask = maskLayer
    }
}

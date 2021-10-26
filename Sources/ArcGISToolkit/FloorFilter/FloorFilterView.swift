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

protocol FloorFilterViewControllerDelegate {
    // Updates the Floor Filter levels list with the site and facility that were selected from the prompt
    func siteFacilityIsUpdated(viewModel: FloorFilterViewModel)
}

public class FloorFilterView: UIViewController, FloorFilterViewControllerDelegate {
    
    /// Public variables and functions accessible to the developer
    public var selectedSite: AGSFloorSite? {
        return viewModel.selectedSite
    }
    
    public var selectedFacility: AGSFloorFacility? {
        return viewModel.selectedFacility
    }
    
    public var selectedLevel: AGSFloorLevel? {
        return viewModel.selectedLevel
    }
    
    /// Listener when a level is changed
    public var onSelectedLevelChangedListener : (() -> Void)? = nil

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
    public var backgroundColor: UIColor = UIColor(hexString: "#F2F2F7")
    public var selectedTextColor: UIColor = UIColor(hexString: "#004874")
    public var unselectedTextColor: UIColor = UIColor(hexString: "#323236")
    
    // Floor Filter UI Elements and Constraints
    @IBOutlet var floorFilterView: UIView!
    @IBOutlet weak var siteBtn: UIButton!
    @IBOutlet weak var levelsTableView: UITableView!
    @IBOutlet weak var closeBtn: UIButton!
    @IBOutlet weak var floorFilterStackView: UIStackView!
    @IBOutlet weak var closeBtnHeight: NSLayoutConstraint!
    @IBOutlet weak var siteBtnHeight: NSLayoutConstraint!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var closeBtnWidth: NSLayoutConstraint!
    @IBOutlet weak var siteBtnWidth: NSLayoutConstraint!
    @IBOutlet weak var levelCellWidth: NSLayoutConstraint!
    
    // Floor Filter view styles variables
    // These are the default, but will get updated with values that are provided during initialization
    private var buttonHeight: Int = 35
    private var buttonWidth: Int = 40
    private var maxDisplayLevels: Int = 3
    private var xMargin: CGFloat = 40.0
    private var yMargin: CGFloat = UIScreen.main.bounds.height - 320
  
    private var delegate: FloorFilterViewControllerDelegate?
    private var viewModel = FloorFilterViewModel()
    
    // State of the visibility of the Floor Filter
    private enum FloorFilterState {
        case initiallyCollapsed
        case partiallyExpanded
        case fullyExpanded
    }
    private var state = FloorFilterState.initiallyCollapsed
    private var isPlacedOnTopOfScreen = false
    
    private var floorManager: AGSFloorManager?
    
    // GeoView that the Floor Filter is rendered on
    // For Version 1 only MapView (2D) is supported to render the Floor Filter
    private var geoView: AGSGeoView? {
        didSet {
            if geoView != nil {
                if let mapView = geoView as? AGSMapView {
                    mapView.map?.load { [weak self] (_) in
                        self?.viewModel.mapView = mapView
                        self?.viewModel.map = mapView.map
                        self?.floorManager = mapView.map?.floorManager
                        self?.initializeFloorManager()
                    }
                }
            }
        }
    }
    
    /// Static method that will be used to initialize the Floor Filter View and attach it as a SubView
    public static func makeFloorFilterView(geoView: AGSGeoView?, buttonWidth: Int = 50, buttonHeight: Int = 50, xMargin: CGFloat = 40, yMargin: CGFloat = UIScreen.main.bounds.height - 320, maxDisplayLevels: Int = 3) -> FloorFilterView? {
     
        let storyboard = UIStoryboard(name: "FloorFilter", bundle: .module)
        let floorFilterVC = storyboard.instantiateViewController(identifier: "FloorFilter") as? FloorFilterView
       
        // Set the styles for the Floor Filter
        floorFilterVC?.buttonHeight = buttonHeight
        floorFilterVC?.buttonWidth = buttonWidth
        floorFilterVC?.xMargin = xMargin
        floorFilterVC?.yMargin = yMargin
        floorFilterVC?.maxDisplayLevels = maxDisplayLevels
        
        // The height is calculated by using the ButtonHeight defined and multiplying by the number of levels displayed on the levels list
        // Since there are two buttons (Close and Site) multiply ButtonHeight by 2
        let height = (buttonHeight * maxDisplayLevels) + (buttonHeight * 2)

        floorFilterVC?.view.frame = CGRect(x: Int(xMargin), y: Int(yMargin), width: buttonWidth, height: height)
        floorFilterVC?.geoView = geoView
      
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
        updateViewsVisibilityForState(state: state)
        initializeSiteButton()
        
        // Adjust the constraints and order of the views in the Floor Filter if placement is on top or bottom of the sceen
        adjustConstraintsBasedOnPlacement()
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
        
        DispatchQueue.main.async {
            floorManager.load(completion: { error in
                if (error != nil || floorManager.loadStatus != .loaded) {
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
            })
        }
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
        state = FloorFilterState.partiallyExpanded
        updateViewsVisibilityForState(state: state)
        self.levelsTableView.reloadData()
    }
    
    private func updateViewsVisibilityForState(state: FloorFilterState) {
        siteBtnHeight.constant = CGFloat(buttonHeight)
        siteBtnWidth.constant = CGFloat(buttonWidth)
        closeBtnWidth.constant = CGFloat(buttonWidth)
        levelCellWidth.constant = CGFloat(buttonWidth)
        closeBtn.backgroundColor = backgroundColor.withAlphaComponent(0.9)
        // by design the close button height will be 3/4th the size of the button size
        closeBtnHeight.constant = CGFloat(Double(buttonHeight) * 0.75)
        addCornerRadiusBasedOnPlacement()
        
        switch state {
        case .fullyExpanded:
            closeBtn?.isHidden = false
            self.levelsTableView?.isHidden = false
            self.tableViewHeight.constant = viewModel.visibleLevelsInExpandedList.count >= maxDisplayLevels ? CGFloat(buttonHeight * maxDisplayLevels) : CGFloat(buttonHeight * viewModel.visibleLevelsInExpandedList.count)
        
        case .partiallyExpanded:
            closeBtn?.isHidden = true
            self.levelsTableView?.isHidden = false
            siteBtnHeight.constant = CGFloat(buttonHeight)
            tableViewHeight.constant = CGFloat(buttonHeight)
            
        case .initiallyCollapsed:
            closeBtn?.isHidden = true
            self.levelsTableView?.isHidden = true
        }
    }
    
    func siteFacilityIsUpdated(viewModel: FloorFilterViewModel) {
        self.viewModel = viewModel
        state = FloorFilterState.fullyExpanded
        updateViewsVisibilityForState(state: state)
        self.levelsTableView.reloadData()
    }
    
    private func addShadow() {
        floorFilterView.layer.shadowColor = UIColor.gray.cgColor
        floorFilterView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        floorFilterView.layer.shadowOpacity = 0.8
    }
    
    private func addCornerRadiusBasedOnPlacement() {
        // Add a corner radius to each of the views
        // Depending on the placement of the Floor Filter and the current state
        if (isPlacedOnTopOfScreen) {
            switch state {
            case .fullyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                closeBtn?.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                levelsTableView.visibleCells.forEach {
                    $0.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 0.0, height: 0.0))
                }
            
            case .partiallyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                levelsTableView.visibleCells.forEach {
                    $0.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                }
                
            case .initiallyCollapsed:
                siteBtn?.cornerRadius(usingCorners: .allCorners, cornerRadii: CGSize(width: 5.0, height: 5.0))
            }
        } else {
            switch state {
            case .fullyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                closeBtn?.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                levelsTableView.visibleCells.forEach {
                    $0.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 0.0, height: 0.0))
                }
            
            case .partiallyExpanded:
                siteBtn?.cornerRadius(usingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                levelsTableView.visibleCells.forEach {
                    $0.cornerRadius(usingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 5.0, height: 5.0))
                }
                
            case .initiallyCollapsed:
                siteBtn?.cornerRadius(usingCorners: .allCorners, cornerRadii: CGSize(width: 5.0, height: 5.0))
            }
        }
    }
    
    private func adjustConstraintsBasedOnPlacement() {
        guard let floorFilterStackView = floorFilterStackView else { return }
        
        let heightOfExpandedView = (buttonHeight * maxDisplayLevels) + (buttonHeight * 2)
        let yPositionOfFloorFilterView = UIScreen.main.bounds.height - CGFloat(yMargin) - CGFloat(heightOfExpandedView)
        
        // If the defined Y Margin is less than half the screen height, then Floor Filter opens downwards
        isPlacedOnTopOfScreen = yPositionOfFloorFilterView >= (UIScreen.main.bounds.height / 2)
        addCornerRadiusBasedOnPlacement()
        // Always center the stack view's x axis to the superview regardless of placement
        let stackViewCenterXConstraint = NSLayoutConstraint(item: floorFilterStackView, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0)
        
        // First remove the Close Button and Site Button from the stack and then based on placement add the Buttons
        floorFilterStackView.removeArrangedSubview(closeBtn)
        floorFilterStackView.removeArrangedSubview(siteBtn)
        floorFilterStackView.setNeedsLayout()
        floorFilterStackView.layoutIfNeeded()
        
        if (isPlacedOnTopOfScreen) {
            let stackViewTopConstraint = NSLayoutConstraint(item: floorFilterStackView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: 0)
            self.view.addConstraints([stackViewTopConstraint, stackViewCenterXConstraint])
            
            // Place the Site Button at the top of the Floor Filter View
            // The Levels List will be unchanged and remain as the second element on the Floor Filter view
            // Place the Close Button at the bottom of the list
            floorFilterStackView.insertArrangedSubview(siteBtn, at: 0)
            floorFilterStackView.insertArrangedSubview(closeBtn, at: 2)
            floorFilterStackView.setNeedsLayout()
        } else {
            let stackViewBottomConstraint = NSLayoutConstraint(item: floorFilterStackView, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1, constant: 0)
            self.view.addConstraints([stackViewBottomConstraint, stackViewCenterXConstraint])
            
            // Place the Close Button at the top of the Floor Filter View
            // The Levels List will be unchanged and remain as the second element on the Floor Filter view
            // Place the Site Button at the bottom of the list
            floorFilterStackView.insertArrangedSubview(closeBtn, at: 0)
            floorFilterStackView.insertArrangedSubview(siteBtn, at: 2)
            floorFilterStackView.setNeedsLayout()
        }
    }
}

extension FloorFilterView: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return state == .partiallyExpanded ? 1 : viewModel.visibleLevelsInExpandedList.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "levelCell", for: indexPath)
        let levels = viewModel.visibleLevelsInExpandedList
        
        // Style the cell
        cell.heightAnchor.constraint(equalToConstant: CGFloat(buttonHeight)).isActive = true
        cell.widthAnchor.constraint(equalToConstant: CGFloat(buttonWidth)).isActive = true
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.font = UIFont(name: fontName, size: fontSize)
        cell.backgroundColor = backgroundColor
        cell.textLabel?.textColor = unselectedTextColor
        
        // If the Floor Filter state is fully expanded then set the title of the cell based on the levels list
        // Otherwise set the title of cell to the selected level short name
        if (state == .fullyExpanded) {
            if (!levels.isEmpty) {
                cell.textLabel?.text = levels[indexPath.row].shortName
            }
        } else {
            cell.textLabel?.text = viewModel.selectedLevel?.shortName
        }
       
        if let selectedLevel = viewModel.selectedLevel {
           if (cell.textLabel?.text == selectedLevel.shortName) {
            cell.backgroundColor = selectionColor
            cell.textLabel?.textColor = selectedTextColor
           }
        } else {
            // When no level is selected, then use the default vertical order as the selected level
            let defaultLevel = levels.first { $0.verticalOrder == viewModel.defaultVerticalOrder }
            viewModel.selectedLevel = defaultLevel
            
            if (cell.textLabel?.text == defaultLevel?.shortName) {
                cell.backgroundColor = selectionColor
            }
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
        // Do not set the selected level
        if (state == .partiallyExpanded) {
            state = .fullyExpanded
            updateViewsVisibilityForState(state: state)
        }
        
        viewModel.filterMapToSelectedLevel()
        levelsTableView.reloadData()
    }
}

// Extensions for UIViewController to get the top most view controller of the application
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

// Extension for UI Color to convert a HexString to UIColor
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

// Extension for UIView to add corner radius 
extension UIView {
    func cornerRadius(usingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: cornerRadii)
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        self.layer.mask = maskLayer
    }
}

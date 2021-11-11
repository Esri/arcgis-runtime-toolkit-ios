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

import Foundation
import UIKit
import ArcGIS
import ArcGISToolkit

class FloorFilterExample2: MapViewController, BookmarksViewControllerDelegate, UISearchBarDelegate, UIPopoverPresentationControllerDelegate {
    var floorFilterVC: FloorFilterView?
    var scalebar: Scalebar?
    var bookmarksVC: BookmarksViewController?
    var bookmarksButton = UIBarButtonItem()
    
    lazy var searchBar:UISearchBar = UISearchBar(frame: CGRect(x: 10, y: 95, width: UIScreen.main.bounds.width - 20, height: 45))

   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the map from a portal item and assign to the mapView.
        let portal = AGSPortal(url: URL(string: "https://indoors.maps.arcgis.com/")!, loginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "f55a743dc53c4503b85c36363b0cfed8")
        let map = AGSMap(item: portalItem)
        mapView.map = map
        mapView.map?.basemap = AGSBasemap.topographicVector()
    
        self.floorFilterVC = FloorFilterView.makeFloorFilterView(geoView: mapView)
        if let floorFilterVC = self.floorFilterVC {
            self.view.addSubview(floorFilterVC.view)
            self.addChild(floorFilterVC)
            floorFilterVC.didMove(toParent: self)
        }
        

        let width = CGFloat(250)
        let xMargin = CGFloat(UIScreen.main.bounds.width - 250)
        let yMargin = CGFloat(15)

        // lower left scalebar
        let sb = Scalebar(mapView: mapView)
        sb.units = .metric
        sb.alignment = .left
        sb.style = .alternatingBar
        view.addSubview(sb)

        // add constraints so it's anchored to lower left corner
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.widthAnchor.constraint(equalToConstant: width).isActive = true
        sb.bottomAnchor.constraint(equalTo: mapView.attributionTopAnchor, constant: -yMargin).isActive = true
        sb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: xMargin).isActive = true
        scalebar = sb

        bookmarksButton = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(showBookmarks))
        navigationItem.rightBarButtonItem = bookmarksButton


        // Create the BookmarksTableViewController.
        bookmarksVC = BookmarksViewController(geoView: mapView)

        // Add a cancel button.
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        bookmarksVC?.navigationItem.rightBarButtonItem = cancelButton
        bookmarksVC?.delegate = self

        searchBar.searchBarStyle = UISearchBar.Style.default
       searchBar.placeholder = " Search in Terminal 1"
       searchBar.sizeToFit()
       searchBar.isTranslucent = true
        searchBar.backgroundColor = UIColor.systemGray6
       searchBar.backgroundImage = UIImage()
       searchBar.delegate = self
        self.view.addSubview(searchBar)

        // Create the compass and add it to our view.
        let compass = Compass(mapView: mapView)
        compass.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(compass)

        // Get the superview's layout.
        let margins = view.layoutMarginsGuide
        compass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 105.0).isActive = true
        compass.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
       
    }
    
    @objc
    func showBookmarks() {
        if let bookmarksVC = bookmarksVC {
            // Display the bookmarksVC as a popover controller.
            bookmarksVC.modalPresentationStyle = .popover
            if let popoverPresentationController = bookmarksVC.popoverPresentationController {
                popoverPresentationController.delegate = self
                popoverPresentationController.barButtonItem = bookmarksButton
            }
            present(bookmarksVC, animated: true)
        }
    }
    
    @objc
    func cancel() {
        dismiss(animated: true)
    }

    func bookmarksViewController(_ controller: BookmarksViewController, didSelect bookmark: AGSBookmark) {
        if let viewpoint = bookmark.viewpoint {
            mapView.setViewpoint(viewpoint, duration: 2.0)
            dismiss(animated: true)
        }
    }
    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.searchBar.showsCancelButton = true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.text = ""
        self.searchBar.resignFirstResponder()
        self.searchBar.endEditing(true)
    }
    
    public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.searchBar.resignFirstResponder()
        self.searchBar.endEditing(true)
    }
}

extension FloorFilterExample: UIPopoverPresentationControllerDelegate {
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}


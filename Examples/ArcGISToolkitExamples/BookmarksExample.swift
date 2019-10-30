//
// Copyright 2019 Esri.

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
import ArcGISToolkit
import ArcGIS

class BookmarksExample: MapViewController {
    var bookmarksVC: BookmarksTableViewController?
    var bookmarksButton = UIBarButtonItem()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Bookmark button that will display the BookmarksTableViewController.
        bookmarksButton = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(showBookmarks))
        navigationItem.rightBarButtonItem = bookmarksButton

        // Create the map from a portal item and assign to the mapView.
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "4e4a4c5753f5401d85d42eb50b12243c")
        mapView.map = AGSMap(item: portalItem)
        
        // Create the BookmarksTableViewController.
        bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewController(geoView: mapView)
    }
    
    @objc
    func showBookmarks() {
        if let bookmarksVC = self.bookmarksVC {
            // If bookmarksVC.selectAction is not set, the default behavior when a user clicks a new bookmark is to
            // call `mapView.setViewpoint(viewpoint)`.  This will pan/zoom the map immediately to the viewpoint.
            // Here we're setting a custom `bookmarkSelectedHandler` that will perform the pan/zoom with a duration (i.e. animation)
            // and then pop the bookmarksVC off the navigation controller stack.
            bookmarksVC.bookmarkSelectedHandler  = { [weak self] (bookmark: AGSBookmark) in
                if let viewpoint = bookmark.viewpoint {
                    self?.mapView.setViewpoint(viewpoint, duration: 2.0)
                    self?.navigationController?.popViewController(animated: true)
                }
            }
            
            // Push the BookmarksTableViewController onto the navigation controller stack.
            navigationController?.pushViewController(bookmarksVC, animated: true)
        }
    }
}

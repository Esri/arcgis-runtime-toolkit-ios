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

class BookmarksExample: MapViewController, BookmarksViewControllerDelegate {
    var bookmarksVC: BookmarksViewController?
    var bookmarksButton = UIBarButtonItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Bookmark button that will display the BookmarksTableViewController.
        bookmarksButton = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(showBookmarks))
        navigationItem.rightBarButtonItem = bookmarksButton

        // Create the map from a portal item and assign to the mapView.
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "16f1b8ba37b44dc3884afc8d5f454dd2")
        mapView.map = AGSMap(item: portalItem)
        
        // Create the BookmarksTableViewController.
        bookmarksVC = BookmarksViewController(geoView: mapView)
        
        // Add a cancel button.
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        bookmarksVC?.navigationItem.rightBarButtonItem = cancelButton
        bookmarksVC?.delegate = self
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
}

extension BookmarksExample: UIPopoverPresentationControllerDelegate {
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

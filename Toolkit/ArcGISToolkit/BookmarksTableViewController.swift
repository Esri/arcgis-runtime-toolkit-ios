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
import ArcGIS

public class BookmarksTableViewController: UITableViewController {
    public typealias BookmarkSelectAction = (AGSBookmark) -> Void

    /// The `AGSGeoView` containing either an `AGSMap` or `AGSScene` with the `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var geoView: AGSGeoView? {
        didSet {
            if let mapView = geoView as? AGSMapView {
                mapView.map?.load { [weak self] (error) in
                    if let error = error {
                        print("Error loading map: \(error)")
                    }
                    self?.bookmarks = mapView.map?.bookmarks as? [AGSBookmark] ?? []
                }
            } else if let sceneView = geoView as? AGSSceneView {
                sceneView.scene?.load { [weak self] (error) in
                    if let error = error {
                        print("Error loading scene: \(error)")
                    }
                    self?.bookmarks = sceneView.scene?.bookmarks as? [AGSBookmark] ?? []
                }
            }
        }
    }
        
    /// The array of `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var bookmarks = [AGSBookmark]() {
        didSet {
            tableView.reloadData()
        }
    }
    
    /// The code block to be executed when the user selects a new bookmark.
    /// If `nil`, the `geoView.setViewpoint` method will be called with the viewpoint of the selected bookmark.
    /// If both `selectAction` and `geoView` are nil, no action is taken when the user selects a bookmark.
    /// - Since: 100.7.0
    public var selectAction: BookmarkSelectAction?

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("use the method `makeBookmarksTableViewController` instead")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Static factory method to instantiate the view controller from a storyboard using bookmarks from either a map or scene in the given `AGSGeoView`.
    /// - Since: 100.7.0
    public static func makeBookmarksTableViewController(geoView: AGSGeoView? = nil) -> BookmarksTableViewController? {
        // create the bookmarks VC from the storyboard
        let bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewControllerInternal()
        bookmarksVC?.geoView = geoView
        
        return bookmarksVC
    }
    
    /// Static factory method to instantiate the view controller from a storyboard using the given `AGSBookmark` array.
    /// - Since: 100.7.0
    public static func makeBookmarksTableViewController(bookmarks: [AGSBookmark] = []) -> BookmarksTableViewController? {
        // create the bookmarks VC from the storyboard
        let bookmarksVC = BookmarksTableViewController.makeBookmarksTableViewControllerInternal()
        bookmarksVC?.bookmarks = bookmarks
        
        return bookmarksVC
    }
    
    /// Common internal method for actually creating the storyboard and view controller.
    private static func makeBookmarksTableViewControllerInternal() -> BookmarksTableViewController? {
        // get the bundle and then the storyboard
        let bundle = Bundle(for: BookmarksTableViewController.self)
        let storyboard = UIStoryboard(name: "BookmarksTableViewController", bundle: bundle)
        
        // create the bookmarks VC from the storyboard and return
        return storyboard.instantiateInitialViewController() as? BookmarksTableViewController
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        tableView.reloadData()
    }

    // MARK: - Table view data source

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.text = bookmarks[indexPath.row].name
        return cell
    }
    
    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // If we have a selectAction, then call it; otherwise set the geoView's viewpoint if available.
        if selectAction != nil {
            selectAction?(bookmarks[indexPath.row])
        } else if let geoView = geoView, let viewpoint = bookmarks[indexPath.row].viewpoint {
            geoView.setViewpoint(viewpoint)
        }

        tableView.deselectRow(at: indexPath, animated: true)
        
        // If we have a navigation controller, pop us off the stack; otherwise just dismiss.
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

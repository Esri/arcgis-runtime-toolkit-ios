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

/// The protocol you implement to respond to user bookmark selection.
/// view controller.
/// - Since: 100.7.0
public protocol BookmarksViewControllerDelegate: AnyObject {
    /// Tells the delegate that the user has selected a bookmark.
    ///
    /// - Parameters:
    ///   - bookmark: The new bookmark selected.
    /// - Since: 100.7.0
    func bookmarkSelectionDidChange(_ bookmark: AGSBookmark)
}

/// The `BookmarksViewController` will display a list of bookmarks in a table view and allows the user to select a bookmark and perform some action.
/// It can be created using either an `AGSGeoView` or an array of `AGSBookmark`s.  When created using an `AGSGeoView`, selecting a bookmark from the list will
/// pan/zoom the geoView to the bookmark's viewpoint.  Users can change this default behavior by supplying a custom handler to the `bookmarkSelectedHandler` property.
/// When created using an array of `AGSBookmarks`, there is no default `bookmarkSelectedHandler` and the user must provide their own.
/// - Since: 100.7.0
public class BookmarksViewController: UIViewController {
    public typealias BookmarkSelectedFunction = (AGSBookmark) -> Void

    /// The array of `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var bookmarks = [AGSBookmark]() {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tableViewController.bookmarks = self.bookmarks
            }
        }
    }
    
    /// The `AGSGeoView` containing either an `AGSMap` or `AGSScene` with the `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var geoView: AGSGeoView? {
        didSet {
            geoViewDidChange(oldValue)
        }
    }
    
    /// The delegate of the bookmarks view controller.  Clients must supply a delegate if they want to be notified when a bookmark is selected so they can perform some action.
    /// If no delegate is supplied, the default behavior is to zoom to the bookmark's viewpoint and dismiss the controller.
    /// If a delegate is supplied, the delegate is responsible for dismissing the controller.
    /// - Since: 100.7.0
    public weak var delegate: BookmarksViewControllerDelegate?

    /// The observations used to observe changes to the bookmarks and map/scene.
    private var bookmarksObservation: NSKeyValueObservation?
    private var mapOrSceneObservation: NSKeyValueObservation?
    
    /// The view controller which handles the actual bookmark display and user interaction.
    private lazy var tableViewController = BookmarksTableViewController()

    /// Returns a BookmarksViewController which will display the `AGSBookmark`s in the `bookmarks` array.
    /// - Parameter bookmarks: The array of `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public init<S: Sequence>(bookmarks: S) where S.Element == AGSBookmark {
        super.init(nibName: nil, bundle: nil)
        self.bookmarks.append(contentsOf: bookmarks)
    }
    
    /// Returns a BookmarksViewController which will display the array of `AGSBookmark` found in the `AGSGeoView`s `AGSMap` or `AGSScene`.
    /// - Parameter geoView: The `AGSGeoView` containing the `AGSBookmark` array in either the map or scene.
    /// - Since: 100.7.0
    public init(geoView: AGSGeoView) {
        super.init(nibName: nil, bundle: nil)
        self.geoView = geoView
        geoViewDidChange(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(*, unavailable)
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("use the methods `init(bookmarks:)` or `init(geoView:)` instead")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup our internal BookmarksTableViewController and add it as a child.
        addChild(tableViewController)
        view.addSubview(tableViewController.view)
        tableViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            tableViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableViewController.didMove(toParent: self)
        
        tableViewController.delegate = self
    }

    private func geoViewDidChange(_ previousGeoView: AGSGeoView?) {
        if let mapView = geoView as? AGSMapView {
            mapView.map?.load { [weak self] (error) in
                if let error = error {
                    print("Error loading map: \(error)")
                }
                self?.bookmarks = (self?.geoView as? AGSMapView)?.map?.bookmarks as? [AGSBookmark] ?? []
            }
            
            // Add an observer to handle changes to the map.bookmarks array.
            bookmarksObservation = mapView.map?.observe(\.bookmarks) { [weak self] (map, _) in
                self?.bookmarks = map.bookmarks as? [AGSBookmark] ?? []
            }
            
            // Add an observer to handle changes to the mapView.map.
            mapOrSceneObservation = mapView.observe(\.map) { [weak self] (_, _) in
                self?.bookmarks = mapView.map?.bookmarks as? [AGSBookmark] ?? []
            }
        } else if let sceneView = geoView as? AGSSceneView {
            sceneView.scene?.load { [weak self] (error) in
                if let error = error {
                    print("Error loading scene: \(error)")
                }
                self?.bookmarks = (self?.geoView as? AGSSceneView)?.scene?.bookmarks as? [AGSBookmark] ?? []
            }
            
            // Add an observer to handle changesto the scene.bookmarks array.
            bookmarksObservation = sceneView.scene?.observe(\.bookmarks) { [weak self] (scene, _) in
                self?.bookmarks = scene.bookmarks as? [AGSBookmark] ?? []
            }
            
            // Add an observer to handle changes to the sceneView.scene.
            mapOrSceneObservation = sceneView.observe(\.scene) { [weak self] (_, _) in
                self?.bookmarks = sceneView.scene?.bookmarks as? [AGSBookmark] ?? []
            }
        }
    }
}

// MARK: BookmarksViewControllerDelegate
extension BookmarksViewController: BookmarksViewControllerDelegate {
    public func bookmarkSelectionDidChange(_ bookmark: AGSBookmark) {
        if let delegate = delegate {
            delegate.bookmarkSelectionDidChange(bookmark)
        } else if let geoView = geoView, let viewpoint = bookmark.viewpoint {
            // If no `delegate` is supplied and we have a viewpoint, then set the viewpoint on the geoView.
            geoView.setViewpoint(viewpoint)
            
            // If we have a navigation controller, pop us off the stack; otherwise just dismiss.
            if let navigationController = navigationController {
                navigationController.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
        }
    }
}

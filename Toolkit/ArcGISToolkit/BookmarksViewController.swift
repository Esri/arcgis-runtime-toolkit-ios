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

/// The protocol you implement to respond to user bookmark selections.
/// - Since: 100.7.0
public protocol BookmarksViewControllerDelegate: AnyObject {
    /// Tells the delegate that the user has selected a bookmark.
    ///
    /// - Parameters:
    ///   - controller: The view controller calling the delegate method.
    ///   - bookmark: The new bookmark selected.
    /// - Since: 100.7.0
    func bookmarksViewController(_ controller: BookmarksViewController, didSelect bookmark: AGSBookmark)
}

/// The `BookmarksViewController` will display a list of bookmarks in a table view and allows the user to select a bookmark and perform some action.
/// It can be created using either an `AGSGeoView` or an array of `AGSBookmark`s.
/// - Since: 100.7.0
public class BookmarksViewController: UIViewController {
    /// The array of `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var bookmarks = [AGSBookmark]() {
        didSet {
            tableViewController.bookmarks = bookmarks
        }
    }
    
    /// The `AGSGeoView` containing either an `AGSMap` or `AGSScene` with the `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public var geoView: AGSGeoView? {
        didSet {
            geoViewDidChange(oldValue)
        }
    }
    
    /// The delegate of the bookmarks view controller.  Clients must set the `delegate` property and implement the `bookmarksViewController:didSelect` delegate method in order to be notified when a bookmark is selected.
    /// - Since: 100.7.0
    public weak var delegate: BookmarksViewControllerDelegate?

    /// The observations used to observe changes to the bookmarks and map/scene.
    private var bookmarksObservation: NSKeyValueObservation?
    private var mapOrSceneObservation: NSKeyValueObservation?
    
    /// The view controller which handles the actual bookmark display and user interaction.
    private lazy var tableViewController = BookmarksTableViewController()

    /// Returns a BookmarksViewController which will display the `AGSBookmark`s in the `bookmarks` array.
    /// - Parameter bookmarks: A sequence of `AGSBookmark`s to display.
    /// - Since: 100.7.0
    public init<S: Sequence>(bookmarks: S) where S.Element == AGSBookmark {
        super.init(nibName: nil, bundle: nil)
        self.bookmarks.append(contentsOf: bookmarks)
        tableViewController.bookmarks = self.bookmarks
        sharedInit()
    }
    
    /// Returns a BookmarksViewController which will display the array of `AGSBookmark` found in the `AGSGeoView`s `AGSMap` or `AGSScene`.
    /// - Parameter geoView: The `AGSGeoView` containing the `AGSBookmark` array in either the map or scene.
    /// - Since: 100.7.0
    public init(geoView: AGSGeoView) {
        super.init(nibName: nil, bundle: nil)
        self.geoView = geoView
        geoViewDidChange(nil)
        sharedInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func sharedInit() {
        title = "Bookmarks"
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
        
        // Set the closure to be executed when the user selects a bookmark.
        tableViewController.setSelectAction { [weak self] (bookmark: AGSBookmark) in
            guard let self = self, let delegate = self.delegate else { return }
            delegate.bookmarksViewController(self, didSelect: bookmark)
        }
    }

    private func geoViewDidChange(_ previousGeoView: AGSGeoView?) {
        if let mapView = geoView as? AGSMapView {
            mapView.map?.load { [weak self] (error) in
                guard let self = self, let mapView = self.geoView as? AGSMapView else { return }
                if let error = error {
                    print("Error loading map: \(error)")
                } else {
                    self.bookmarks = mapView.map?.bookmarks as? [AGSBookmark] ?? []
                }
            }
            
            // Add an observer to handle changes to the map.bookmarks array.
            addBookmarksObserver(map: mapView.map)

            // Add an observer to handle changes to the mapView.map.
            mapOrSceneObservation = mapView.observe(\.map) { [weak self] (_, _) in
                self?.bookmarks = mapView.map?.bookmarks as? [AGSBookmark] ?? []
                
                // When the map changes, we again need to add an observer to handle changes to the map.bookmarks array.
                self?.addBookmarksObserver(map: mapView.map)
            }
        } else if let sceneView = geoView as? AGSSceneView {
            sceneView.scene?.load { [weak self] (error) in
                guard let self = self, let sceneView = self.geoView as? AGSSceneView else { return }
                if let error = error {
                    print("Error loading map: \(error)")
                } else {
                    self.bookmarks = sceneView.scene?.bookmarks as? [AGSBookmark] ?? []
                }
            }
            
            // Add an observer to handle changesto the scene.bookmarks array.
            addBookmarksObserver(scene: sceneView.scene)
            
            // Add an observer to handle changes to the sceneView.scene.
            mapOrSceneObservation = sceneView.observe(\.scene) { [weak self] (_, _) in
                self?.bookmarks = sceneView.scene?.bookmarks as? [AGSBookmark] ?? []
                
                // When the scene changes, we again need to add an observer to handle changes to the scene.bookmarks array.
                self?.addBookmarksObserver(scene: sceneView.scene)
            }
        }
    }
    
    private func addBookmarksObserver(map: AGSMap?) {
        bookmarksObservation = map?.observe(\.bookmarks) { [weak self] (map, _) in
            DispatchQueue.main.async {
                self?.bookmarks = map.bookmarks as? [AGSBookmark] ?? []
            }
        }
    }
    
    private func addBookmarksObserver(scene: AGSScene?) {
        bookmarksObservation = scene?.observe(\.bookmarks) { [weak self] (scene, _) in
            DispatchQueue.main.async {
                self?.bookmarks = scene.bookmarks as? [AGSBookmark] ?? []
            }
        }
    }
}

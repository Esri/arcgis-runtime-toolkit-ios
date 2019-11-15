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

import XCTest
import ArcGISToolkit
import ArcGIS

class BookmarksViewControllerTests: XCTestCase {
    /// Tests the creation of the `BookmarksViewController` using a list of `AGSBookmark`.
    func testBookmarksList() {
        let bookmarks = generateBookmarks()
        let bookmarksVC = BookmarksViewController(bookmarks: bookmarks)
        XCTAssertEqual(bookmarks.count, bookmarksVC.bookmarks.count)
    }
    
    /// Tests the creation of the `BookmarksViewController` using an `AGSMapView` by verifying the `bookmarks` property returns the correct number of bookmarks.
    func testBookmarksMapView() {
        let mapView = AGSMapView()
        let map = AGSMap(basemap: .streets())
        mapView.map = map
        
        let bookmarks = generateBookmarks()
        map.bookmarks.addObjects(from: bookmarks)

        // Wait for the map to load.  This allows the observers to be set up.
        XCTLoad(map)
        
        // Create the BookmarksViewController.
        let bookmarksVC = BookmarksViewController(geoView: mapView)
        XCTAssertEqual(map.bookmarks.count, bookmarksVC.bookmarks.count)
    }
    
    /// Tests the ability to detect changes to the map and bookmarks array in order to update the list of bookmarks.
    func testChangeMapAndBookmarks() {
        let mapView = AGSMapView()
        let map = AGSMap(basemap: .streets())
        mapView.map = map

        let bookmarks = generateBookmarks()
        map.bookmarks.addObjects(from: bookmarks)
        
        // Wait for the map to load.  This allows the observers to be set up.
        XCTLoad(map)

        // Create the BookmarksViewController.
        let bookmarksVC = BookmarksViewController(geoView: mapView)
        
        // Change the map.
        let newMap = AGSMap(basemap: .imagery())
        newMap.bookmarks.add(AGSBookmark(name: "Mysterious Desert Pattern", viewpoint: AGSViewpoint(latitude: 27.3805833, longitude: 33.6321389, scale: 6e3)))
        mapView.map = newMap
        
        // Wait for the map to load.  This allows the observers to be set up.
        XCTLoad(newMap)
        
        // Check if bookmarks property is updated.
        XCTAssertEqual(newMap.bookmarks.count, bookmarksVC.bookmarks.count)

        // Add bookmark to list.
        mapView.map?.bookmarks.add(AGSBookmark(name: "Strange Symbol", viewpoint: AGSViewpoint(latitude: 37.401573, longitude: -116.867808, scale: 6e3)))

        // Wait for a bit so the bookmark-changed notification can be propagated.
        let exp = XCTestExpectation(description: "generic wait...")
        XCTWaiter().wait(for: [exp], timeout: 2.0)

        // Check if bookmarks property is updated.
        XCTAssertEqual(newMap.bookmarks.count, bookmarksVC.bookmarks.count)
    }
    
    /// Tests the creation of the `BookmarksViewController` using an `AGSSceneView` by verifying the `bookmarks` property returns the correct number of bookmarks
    func testBookmarksSceneView() {
        let sceneView = AGSSceneView()
        let scene = AGSScene(basemap: .streets())
        sceneView.scene = scene

        let bookmarks = generateBookmarks()
        scene.bookmarks.addObjects(from: bookmarks)

        // Wait for the scene to load.  This allows the observers to be set up.
        XCTLoad(scene)

        // Create the BookmarksViewController.
        let bookmarksVC = BookmarksViewController(geoView: sceneView)
        XCTAssertEqual(scene.bookmarks.count, bookmarksVC.bookmarks.count)
    }
    
    /// Tests the ability to detect changes to the scene and bookmarks array in order to update the list of bookmarks.
    func testChangeSceneAndBookmarks() {
        let sceneView = AGSSceneView()
        let scene = AGSScene(basemap: .streets())
        sceneView.scene = scene
        
        let bookmarks = generateBookmarks()
        scene.bookmarks.addObjects(from: bookmarks)
        
        // Wait for the scene to load.  This allows the observers to be set up.
        XCTLoad(scene)

        // Create the BookmarksViewController.
        let bookmarksVC = BookmarksViewController(geoView: sceneView)
        
        // Change the scene.
        let newScene = AGSScene(basemap: .imagery())
        newScene.bookmarks.add(AGSBookmark(name: "Mysterious Desert Pattern", viewpoint: AGSViewpoint(latitude: 27.3805833, longitude: 33.6321389, scale: 6e3)))
        sceneView.scene = newScene
        
        // Wait for the scene to load.  This allows the observers to be set up.
        XCTLoad(newScene)
        
        // Check if bookmarks property is updated.
        XCTAssertEqual(newScene.bookmarks.count, bookmarksVC.bookmarks.count)
        
        // Add bookmark to list.
        sceneView.scene?.bookmarks.add(AGSBookmark(name: "Strange Symbol", viewpoint: AGSViewpoint(latitude: 37.401573, longitude: -116.867808, scale: 6e3)))

        // Wait for a bit so the bookmark-changed notification can be propagated.
        let exp = XCTestExpectation(description: "generic wait...")
        XCTWaiter().wait(for: [exp], timeout: 2.0)
        
        // Check if bookmarks property is updated.
        XCTAssertEqual(newScene.bookmarks.count, bookmarksVC.bookmarks.count)
    }
    
    /// Generates a list of predefined bookmarks for testing.
    func generateBookmarks() -> [AGSBookmark] {
        return [AGSBookmark(name: "Barcelona", viewpoint: AGSViewpoint(latitude: 41.385063, longitude: 2.173404, scale: 6e5)),
                AGSBookmark(name: "Portland", viewpoint: AGSViewpoint(latitude: 44.977753, longitude: -93.265015, scale: 6e5)),
                AGSBookmark(name: "Minneapolis", viewpoint: AGSViewpoint(latitude: 44.977753, longitude: -93.265015, scale: 6e5)),
                AGSBookmark(name: "Edinburgh", viewpoint: AGSViewpoint(latitude: 55.953251, longitude: -3.188267, scale: 6e5))]
    }
}

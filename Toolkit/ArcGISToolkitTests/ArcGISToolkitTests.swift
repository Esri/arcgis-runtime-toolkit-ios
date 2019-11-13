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

class ArcGISToolkitTests: XCTestCase {
    func testComponentCreation() {
        // Compass
        let compass = Compass(mapView: AGSMapView(frame: .zero))
        XCTAssertNotNil(compass)

        // LegendViewController
        var legendVC = LegendViewController.makeLegendViewController(geoView: AGSMapView(frame: .zero))
        XCTAssertNotNil(legendVC)
        
        legendVC = LegendViewController.makeLegendViewController()
        XCTAssertNotNil(legendVC)

        // MeasureToolbar
        let measureToolbar = MeasureToolbar(mapView: AGSMapView(frame: .zero))
        XCTAssertNotNil(measureToolbar)

        // Scalebar
        let scaleBar = Scalebar(mapView: AGSMapView(frame: .zero))
        XCTAssertNotNil(scaleBar)

        // UnitsViewController
        let unitsVC = UnitsViewController()
        XCTAssertNotNil(unitsVC)
        
        // Job Manager
        let jobManager = JobManager.shared
        XCTAssertNotNil(jobManager)
        
        // PopupController
        let vc = UIViewController()
        let popupController = PopupController(geoViewController: vc, geoView: AGSMapView(frame: .zero))
        XCTAssertNotNil(popupController)
        
        // TimeSlider
        let timeSlider = TimeSlider()
        XCTAssertNotNil(timeSlider)

        // BookarksViewController
        var bookmarksVC = BookmarksViewController(geoView: AGSMapView(frame: .zero))
        XCTAssertNotNil(bookmarksVC)

        bookmarksVC = BookmarksViewController(bookmarks: bookmarks())
        XCTAssertNotNil(bookmarksVC)
    }

    private func bookmarks() -> [AGSBookmark] {
        var bookmarks = [AGSBookmark]()
        //create a few bookmarks and add them to the map
        var viewpoint: AGSViewpoint
        var bookmark: AGSBookmark
        
        viewpoint = AGSViewpoint(latitude: 41.385063, longitude: 2.173404, scale: 6e5)
        bookmark = AGSBookmark(name: "Barcelona", viewpoint: viewpoint)
        bookmarks.append(bookmark)
        
        viewpoint = AGSViewpoint(latitude: 45.512230, longitude: -122.658722, scale: 6e5)
        bookmark = AGSBookmark(name: "Portland", viewpoint: viewpoint)
        bookmarks.append(bookmark)
        
        viewpoint = AGSViewpoint(latitude: 44.977753, longitude: -93.265015, scale: 6e5)
        bookmark = AGSBookmark(name: "Minneapolis", viewpoint: viewpoint)
        bookmarks.append(bookmark)
        
        viewpoint = AGSViewpoint(latitude: 55.953251, longitude: -3.188267, scale: 6e5)
        bookmark = AGSBookmark(name: "Edinburgh", viewpoint: viewpoint)
        bookmarks.append(bookmark)

        return bookmarks
    }
}

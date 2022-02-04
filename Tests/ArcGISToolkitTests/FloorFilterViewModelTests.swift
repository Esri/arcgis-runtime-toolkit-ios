//
// Copyright 2022 Esri.

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
@testable import ArcGISToolkit
import ArcGIS

final class FloorFilterViewModelTests: XCTestCase {
    func testSitesData() throws {
        let portal = AGSPortal(url: URL(string: "https://indoors.maps.arcgis.com/")!, loginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "f133a698536f44c8884ad81f80b6cfc7")
        let map = AGSMap(item: portalItem)
        let mapView = AGSMapView()
        mapView.map = map
        
        XCTLoad(map)
        let floorManager = try XCTUnwrap(map.floorManager)
        XCTLoad(floorManager)
        let viewModel = FloorFilterViewModel()
        viewModel.mapView = mapView
        XCTAssertEqual(viewModel.sites.count, 1)
    }
    
    func testFacilitiesData() throws {
        let portal = AGSPortal(url: URL(string: "https://indoors.maps.arcgis.com/")!, loginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "f133a698536f44c8884ad81f80b6cfc7")
        let map = AGSMap(item: portalItem)
        let mapView = AGSMapView()
        mapView.map = map
        
        XCTLoad(map)
        let floorManager = try XCTUnwrap(map.floorManager)
        XCTLoad(floorManager)
        let viewModel = FloorFilterViewModel()
        viewModel.mapView = mapView
        viewModel.selectedSite = viewModel.sites.first
        XCTAssertEqual(viewModel.facilities.count, 1)
    }
    
    func testLevelsData() throws {
        let portal = AGSPortal(url: URL(string: "https://indoors.maps.arcgis.com/")!, loginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "f133a698536f44c8884ad81f80b6cfc7")
        let map = AGSMap(item: portalItem)
        let mapView = AGSMapView()
        mapView.map = map

        XCTLoad(map)
        let floorManager = try XCTUnwrap(map.floorManager)
        XCTLoad(floorManager)
        let viewModel = FloorFilterViewModel()
        viewModel.mapView = mapView
        XCTAssertEqual(viewModel.allLevels.count, 3)
    }
}

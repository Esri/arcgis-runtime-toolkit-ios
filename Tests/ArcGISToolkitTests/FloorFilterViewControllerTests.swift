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

class FloorFilterViewControllerTests: XCTestCase {
    
    func testTopPlacement() {
        let floorFilterView = FloorFilterView.makeFloorFilterView(geoView: AGSGeoView(frame: .zero), xMargin: UIScreen.main.bounds.width - 100, yMargin: 100)
        let xPositionOfFloorFilterView = UIScreen.main.bounds.width - CGFloat(100) - CGFloat(floorFilterView?.view.bounds.width ?? 0)
        XCTAssertEqual(UIScreen.main.bounds.width - 100 - 50, xPositionOfFloorFilterView)
    }
    
    func testBottomPlacement() {
        let floorFilterView = FloorFilterView.makeFloorFilterView(geoView: AGSGeoView(frame: .zero), xMargin: 40, yMargin: UIScreen.main.bounds.height - 300)
        let yPositionOfFloorFilterView = UIScreen.main.bounds.height - CGFloat(300) - CGFloat(floorFilterView?.view.bounds.height ?? 0)
        let expectedHeight = ((50*2)+(50*3)+1)
        XCTAssertEqual(UIScreen.main.bounds.height - 300 - CGFloat(expectedHeight), yPositionOfFloorFilterView)
    }
    
}

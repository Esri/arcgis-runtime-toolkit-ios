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

// View Model class that contains the Data Model of the Floor Filter
// Also contains the business logic to filter and change the map extent based on selected site/level/facility
internal class FloorFilterViewModel {
    
    // The MapView, Map and Floor Manager are set in the FloorFilterViewController when the map is loaded
    public var mapView: AGSMapView?
    public var map: AGSMap?
    public var floorManager: AGSFloorManager?
    
    public var sites: [AGSFloorSite] {
        return floorManager?.sites ?? []
    }
    
    // Facilities in the site that is selected
    // If no site is selected then the list is empty
    // If the sites data does not exist in the map, then use all the facilities in the map
    public var facilities: [AGSFloorFacility] {
        guard let floorManager = floorManager else { return [] }
        return sites.isEmpty ? floorManager.facilities : floorManager.facilities.filter { $0.site == selectedSite }
    }
    
    // Levels that are visible in the expanded Floor Filter levels table view
    // Reverse the order of the levels to make it in ascending order
    public var visibleLevelsInExpandedList: [AGSFloorLevel] {
        guard let floorManager = floorManager else { return [] }
        return facilities.isEmpty ? floorManager.levels : floorManager.levels.filter { $0.facility == selectedFacility }.reversed()
    }
    
    // All the levels in the map
    public var allLevels: [AGSFloorLevel] {
        return floorManager?.levels ?? []
    }
    
    // The site, facility, and level that are selected by the user
    public var selectedSite: AGSFloorSite?
    public var selectedFacility: AGSFloorFacility?
    public var selectedLevel: AGSFloorLevel?
    
    // The default vertical order is 0 according to Runtime 100.12 update for AGSFloorManager
    public let defaultVerticalOrder = 0

    public func reset() {
        floorManager = nil
        selectedSite = nil
        selectedFacility = nil
        selectedLevel = nil
    }
    
    public func getSelectedSite() -> AGSFloorSite? {
        return sites.first { $0 == selectedSite }
    }

    public func getSelectedFacility() -> AGSFloorFacility? {
        return facilities.first { $0 == selectedFacility }
    }
    
    public func getSelectedVisibleLevel() -> AGSFloorLevel? {
        return visibleLevelsInExpandedList.first { $0 == selectedLevel }
    }
    
    // Sets the visibility of all the levels on the map based on the vertical order of the current selected level
    public func filterMapToSelectedLevel() {
        guard let selectedLevel = getSelectedVisibleLevel() ?? selectedLevel else { return }
        allLevels.forEach {
            $0.isVisible = $0.verticalOrder == selectedLevel.verticalOrder
        }
    }
    
    // Zooms to the facility if there is a selected facility, otherwise zooms to the site if there is no selected facility
    public func zoomToSelection() {
        if let _ = selectedFacility {
            zoomToFacility()
        } else {
            if let _ = selectedSite {
                zoomToSite()
            }
        }
    }
    
    private func zoomToSite() {
        zoomToExtent(mapView: mapView, envelope: getSelectedSite()?.geometry?.extent)
    }
    
    private func zoomToFacility() {
        zoomToExtent(mapView: mapView, envelope: getSelectedFacility()?.geometry?.extent)
    }
    
    private func zoomToExtent(mapView: AGSMapView?, envelope: AGSEnvelope?, padding: Double = 1.5) {
        if let mapView = mapView, let envelope = envelope {
            let envelopeWithBuffer = AGSEnvelope(center: envelope.center, width: envelope.width * padding, height: envelope.height * padding)
            if (!envelopeWithBuffer.isEmpty) {
                let viewPoint = AGSViewpoint(targetExtent: envelopeWithBuffer)
                DispatchQueue.main.async {
                    mapView.setViewpoint(viewPoint, duration: 0.5, completion: nil)
                }
            }
            
        }
    }
}
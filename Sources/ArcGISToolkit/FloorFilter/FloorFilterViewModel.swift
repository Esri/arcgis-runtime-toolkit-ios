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

/// View Model class that contains the Data Model of the Floor Filter
/// Also contains the business logic to filter and change the map extent based on selected site/level/facility
final class FloorFilterViewModel {
    /// The MapView, Map and Floor Manager are set in the FloorFilterViewController when the map is loaded
    var mapView: AGSMapView?
    
    var floorManager: AGSFloorManager? {
        return mapView?.map?.floorManager
    }
    
    var sites: [AGSFloorSite] {
        return floorManager?.sites ?? []
    }
    
    /// Facilities in the selected site
    /// If no site is selected then the list is empty
    /// If the sites data does not exist in the map, then use all the facilities in the map
    var facilities: [AGSFloorFacility] {
        guard let floorManager = floorManager else { return [] }
        return sites.isEmpty ? floorManager.facilities : floorManager.facilities.filter { $0.site == selectedSite }
    }
    
    /// Levels that are visible in the expanded Floor Filter levels table view
    /// Sort the levels by verticalOrder in a descending order
    var visibleLevelsInExpandedList: [AGSFloorLevel] {
        guard let floorManager = floorManager else { return [] }
        return facilities.isEmpty ? floorManager.levels : floorManager.levels.filter {
            $0.facility == selectedFacility
        }.sorted {
            $0.verticalOrder > $1.verticalOrder
        }
    }
    
    /// All the levels in the map
    /// make this property public so it can be accessible to test 
    var allLevels: [AGSFloorLevel] {
        return floorManager?.levels ?? []
    }
    
    /// The site, facility, and level that are selected by the user
    var selectedSite: AGSFloorSite?
    var selectedFacility: AGSFloorFacility?
    var selectedLevel: AGSFloorLevel?
    
    /// Gets the default level for a facility
    /// Uses level with vertical order 0 otherwise gets the lowest level
    func defaultLevel(for facility: AGSFloorFacility?) -> AGSFloorLevel? {
        let candidateLevels = allLevels.filter { $0.facility == facility }
        return candidateLevels.first { $0.verticalOrder == 0 } ?? lowestLevel()
    }
    
    /// Returns the AGSFloorLevel with the lowest verticalOrder.
    private func lowestLevel() -> AGSFloorLevel? {
        let sortedLevels = allLevels.sorted {
            $0.verticalOrder < $1.verticalOrder
        }
        return sortedLevels.first {
            $0.verticalOrder != .min && $0.verticalOrder != .max
        }
    }
    
    /// Sets the visibility of all the levels on the map based on the vertical order of the current selected level
    func filterMapToSelectedLevel() {
        guard let selectedLevel = selectedLevel else { return }
        allLevels.forEach {
            $0.isVisible = $0.verticalOrder == selectedLevel.verticalOrder
        }
    }
    
    /// Zooms to the facility if there is a selected facility, otherwise zooms to the site.
    func zoomToSelection() {
        if let selectedFacility = selectedFacility {
            zoom(to: selectedFacility)
        } else if let selectedSite = selectedSite {
            zoom(to: selectedSite)
        }
    }
    
    private func zoom(to floorSite: AGSFloorSite) {
        zoomToExtent(mapView: mapView, envelope: floorSite.geometry?.extent)
    }
    
    private func zoom(to floorFacility: AGSFloorFacility) {
        zoomToExtent(mapView: mapView, envelope: floorFacility.geometry?.extent)
    }
    
    private func zoomToExtent(mapView: AGSMapView?, envelope: AGSEnvelope?) {
        guard let mapView = mapView,
              let envelope = envelope
        else { return }
            
        let padding = 1.5
        let envelopeWithBuffer = AGSEnvelope(
            center: envelope.center,
            width: envelope.width * padding,
            height: envelope.height * padding
        )
            
        if !envelopeWithBuffer.isEmpty {
            let viewPoint = AGSViewpoint(targetExtent: envelopeWithBuffer)
            mapView.setViewpoint(viewPoint, duration: 0.5, completion: nil)
        }
    }
}

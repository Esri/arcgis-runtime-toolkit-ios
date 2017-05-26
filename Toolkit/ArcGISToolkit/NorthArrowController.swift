// Copyright 2016 Esri.

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

public class NorthArrowController: NSObject {
    
    var mapView : AGSMapView
    var northArrowView : UIView
    private var kvoContext = 0
    
    public init(mapView: AGSMapView, northArrowView: UIView) {
        self.mapView = mapView
        self.northArrowView = northArrowView
        
        super.init()
        
        // Add NorthArrowController as an observer of the mapView's rotation.
        self.mapView.addObserver(self, forKeyPath: #keyPath(AGSMapView.rotation), options: [], context: &kvoContext)
    }
    
    deinit {
        // Stop observing the map view's rotation.
        self.mapView.removeObserver(self, forKeyPath: #keyPath(AGSMapView.rotation), context: &kvoContext)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == #keyPath(AGSMapView.rotation)) && (context == &kvoContext) {
            // Rotate north arrow to match the map view rotation.
            let mapRotation = self.degreesToRadians(degrees: (360 - self.mapView.rotation))
            let transform = CGAffineTransform(rotationAngle: mapRotation)
            self.northArrowView.transform = transform
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func degreesToRadians(degrees : Double) -> CGFloat {
        return CGFloat(degrees * M_PI / 180)
    }
}

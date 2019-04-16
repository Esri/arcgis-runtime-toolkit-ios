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
import ARKit
import ArcGIS

class ArcGISARView: UIView {
    
    public private(set) var session: ARSession?
    
    public private(set) var sceneView: AGSSceneView?
    
    public var originCamera: AGSCamera?

    public var translationTransformationFactor: Double = 1.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInitialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    required public init(renderVideoFeed: Bool){
        super.init(frame: CGRect.zero)
        sharedInitialization()
    }
    
    private func sharedInitialization(){
        
    }
    
    public func arScreenToLocation(screenPoint: AGSPoint) -> AGSPoint {
        return AGSPoint(x: 0.0, y: 0.0, spatialReference: nil)
    }
    
    public func resetTracking() {
        
    }

    public func resetUsingLocationServices() -> Bool {
        return false
    }
    
    public func resetUsingSpatialAnchor() -> Bool {
        return false
    }
    
    public func startTracking() {
        
    }

    public func stopTracking() {
        
    }
}

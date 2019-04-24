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
//import ArcGISToolkit
//import ArcGIS

open class ARExample: UIViewController {
    
    public let arView = ArcGISARView(frame: CGRect.zero)
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        arView.frame = view.bounds
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        arView.sceneView.scene = AGSScene(basemapType: .streets)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        arView.startTracking()
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        arView.stopTracking()
    }
}


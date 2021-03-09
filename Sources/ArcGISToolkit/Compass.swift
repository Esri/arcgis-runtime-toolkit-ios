// Copyright 2017 Esri.

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

public class Compass: UIImageView {
    public var heading: Double = 0.0 { // Rotation - bound to MapView.MapRotation
        didSet {
            mapView.setViewpointRotation(heading, completion: nil)
        }
    }
    public var autoHide: Bool = true { // Auto hides when north is up
        didSet {
            animateCompass()
        }
    }
    public var width: CGFloat = 30.0 {
        didSet {
            widthConstraint?.isActive = false
            widthConstraint = widthAnchor.constraint(equalToConstant: width)
            widthConstraint?.isActive = true
        }
    }
    public var height: CGFloat = 30 {
        didSet {
            heightConstraint?.isActive = false
            heightConstraint = heightAnchor.constraint(equalToConstant: height)
            heightConstraint?.isActive = true
        }
    }
    
    private var mapView: AGSMapView
    
    // the width and height constraints
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    private var rotationObservation: NSKeyValueObservation?
    
    public init(mapView: AGSMapView) {
        self.mapView = mapView
        
        super.init(frame: .zero)
        
        // Set our image to the CompassIcon in the Assets
        image = UIImage(named: "CompassIcon", in: .module, compatibleWith: nil)
        
        // add gesture recognizer to know when arrow is tapped
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(compassTapped))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.isUserInteractionEnabled = true
        
        // animate the compass visibility, if necessary
        animateCompass()
        
        // Add Compass as an observer of the mapView's rotation.
        rotationObservation = mapView.observe(\.rotation, options: .new) {[weak self] (_, change) in
            guard let rotation = change.newValue else {
                return
            }
            
            // make sure that UI changes are made on the main thread
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                
                let mapRotation = self.degreesToRadians(degrees: (360 - rotation))
                // Rotate north arrow to match the map view rotation.
                self.transform = CGAffineTransform(rotationAngle: mapRotation)
                // Animate the compass visibility (if necessary)
                self.animateCompass()
            }
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    func compassTapped() {
        mapView.setViewpointRotation(0, completion: nil)
    }
    
    func animateCompass() {
        let alpha: CGFloat = (mapView.rotation == 0.0) && autoHide ? 0.0 : 1.0
        if alpha != self.alpha {
            UIView.animate(withDuration: 0.25) {
                self.alpha = alpha
            }
        }
    }
    
    func degreesToRadians(degrees: Double) -> CGFloat {
        return CGFloat(degrees * Double.pi / 180)
    }
}

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
    private var kvoContext = 0
    
    // the width and height constraints
    private var widthConstraint:NSLayoutConstraint?
    private var heightConstraint:NSLayoutConstraint?

    public init(mapView: AGSMapView) {
        self.mapView = mapView
        
        super.init(frame: .zero)
        
        // Add NorthArrowController as an observer of the mapView's rotation.
        mapView.addObserver(self, forKeyPath: #keyPath(AGSMapView.rotation), options: [], context: &kvoContext)
        
        // Set our image to the CompassIcon in the Assets
        let bundle = Bundle(for: type(of: self))
        image = UIImage(named: "CompassIcon", in: bundle, compatibleWith: nil)
        
        // add gesture recognizer to know when arrow is tapped
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(compassTapped))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.isUserInteractionEnabled = true
        
        // animate the compass visibility, if necessary
        animateCompass()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // Stop observing the map view's rotation.
        mapView.removeObserver(self, forKeyPath: #keyPath(AGSMapView.rotation), context: &kvoContext)
    }
    
    @objc func compassTapped(){
        mapView.setViewpointRotation(0, completion: nil)
        isHidden = autoHide
    }
    
    func animateCompass() {
        let alpha: CGFloat = (mapView.rotation == 0.0) && autoHide ? 0.0 : 1.0
        if alpha != self.alpha {
            UIView.animate(withDuration: 0.25) {
                self.alpha = alpha
            }
        }
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == #keyPath(AGSMapView.rotation)) && (context == &kvoContext) {
            // Rotate north arrow to match the map view rotation.
            let mapRotation = self.degreesToRadians(degrees: (360 - mapView.rotation))
            let transform = CGAffineTransform(rotationAngle: mapRotation)
            self.transform = transform
            
            // animate the compass visibility, if necessary
            animateCompass()
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func degreesToRadians(degrees : Double) -> CGFloat {
        return CGFloat(degrees * Double.pi / 180)
    }
}

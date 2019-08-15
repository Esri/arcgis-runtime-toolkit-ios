//
//  CalibrationView.swift
//  ArcGISToolkitExamples
//
//  Created by Mark Dostal on 8/13/19.
//  Copyright © 2019 Esri. All rights reserved.
//

import UIKit
import ArcGIS

/// A view displaying controls for adjusting a scene view's location, heading, and elevation. Used to calibrate an AR session.
class CalibrationView: UIView, UIGestureRecognizerDelegate {
    
    // The scene view displaying the scene.
    private var sceneView: AGSSceneView!

    /// The camera controller used to adjust user interactions.
    private var cameraController: AGSTransformationMatrixCameraController!

    /// The label displaying calibration directions.
    private let calibrationDirectionsLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24.0)
        label.textColor = .darkText
        label.numberOfLines = 0
        label.text = "Calibrating..."
        return label
    }()
    
    /// The UISlider used to adjust elevation.
    private let elevationSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = -100.0
        slider.maximumValue = 100.0
        
        // Rotate the slider so it slides up/down.
        slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)
        return slider
    }()
    
    /// The UISlider used to adjust heading.
    private let headingSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = -180.0
        slider.maximumValue = 180.0
        return slider
    }()
    
    /// The last elevation slider value.
    var lastElevationValue: Float = 0
    
    // The last heading slider value.
    var lastHeadingValue: Float = 0

    /// Initialized a new calibration view with the given scene view and camera controller.
    ///
    /// - Parameters:
    ///   - sceneView: The scene view displaying the scene.
    ///   - cameraController: The camera controller used to adjust user interactions.
    init(sceneView: AGSSceneView, cameraController: AGSTransformationMatrixCameraController) {
        super.init(frame: .zero)
        
        self.cameraController = cameraController
        self.sceneView = sceneView

        // Set a corner radius on the directions label.
//        calibrationDirectionsLabel.layer.cornerRadius = 8.0
//        calibrationDirectionsLabel.layer.masksToBounds = true
        
        // Create visual effects view to show the label on a blurred background.
        let labelView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        labelView.layer.cornerRadius = 8.0
        labelView.layer.masksToBounds = true

        // Add the label to our label view and set up constraints.
        labelView.contentView.addSubview(calibrationDirectionsLabel)
        calibrationDirectionsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            calibrationDirectionsLabel.leadingAnchor.constraint(equalTo: labelView.leadingAnchor, constant: 8),
            calibrationDirectionsLabel.trailingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: -8),
            calibrationDirectionsLabel.topAnchor.constraint(equalTo: labelView.topAnchor, constant: 8),
            calibrationDirectionsLabel.bottomAnchor.constraint(equalTo: labelView.bottomAnchor, constant: -8)
            ])
        
        // Add the label view to our view and set up constraints.
        addSubview(labelView)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelView.topAnchor.constraint(equalTo: topAnchor, constant: 88.0)
            ])
        
        // Add the elevation slider.
        addSubview(elevationSlider)
        elevationSlider.addTarget(self, action: #selector(elevationChanged(_:)), for: .valueChanged)
        elevationSlider.translatesAutoresizingMaskIntoConstraints = false
        let width: CGFloat = 500.0
        NSLayoutConstraint.activate([
            elevationSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            elevationSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: width),
            elevationSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: width / 2.0 - 36)
            ])
        
        // Add the heading slider.
        addSubview(headingSlider)
        headingSlider.addTarget(self, action: #selector(headingChanged(_:)), for: .valueChanged)
        headingSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headingSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            headingSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            headingSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If the user tapped in the view (and not in the sliders), do not handle the event.
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            return nil;
        } else {
            return hitView;
        }
    }

    /// Handle an elevation slider value-changed event.
    ///
    /// - Parameter sender: The slider tapped on.
    @objc func elevationChanged(_ sender: UISlider){
        let camera = cameraController.originCamera
        cameraController.originCamera = camera.elevate(withDeltaAltitude: Double(sender.value - lastElevationValue))
        lastElevationValue = sender.value
    }
    
    /// Handle an heading slider value-changed event.
    ///
    /// - Parameter sender: The slider tapped on.
    @objc func headingChanged(_ sender: UISlider){
        let camera = cameraController.originCamera
        let newHeading = Float(camera.heading) + sender.value - lastHeadingValue
        cameraController.originCamera = camera.rotate(toHeading: Double(newHeading), pitch: camera.pitch, roll: camera.roll)
        lastHeadingValue = sender.value
    }
}

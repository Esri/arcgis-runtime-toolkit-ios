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
import ArcGIS
import ArcGISToolkit

/// A view displaying controls for adjusting a scene view's location, heading, and elevation. Used to calibrate an AR session.
class CalibrationView: UIView {
    /// Denotes whether to show the elevation control and label; defaults to `true`.
    var elevationControlVisibility: Bool = true {
        didSet {
            elevationSlider.isHidden = !elevationControlVisibility
            elevationLabel.isHidden = !elevationControlVisibility
        }
    }
    
    /// The `ArcGISARView` containing the origin camera we will be updating.
    private var arcgisARView: ArcGISARView!

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
        slider.minimumValue = -50.0
        slider.maximumValue = 50.0
        return slider
    }()
    
    /// The UISlider used to adjust heading.
    private let headingSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = -10.0
        slider.maximumValue = 10.0
        return slider
    }()
    
    /// The elevation label..
    private let elevationLabel = UILabel(frame: .zero)

    /// Initialized a new calibration view with the `ArcGISARView`.
    ///
    /// - Parameters:
    ///   - arcgisARView: The `ArcGISARView` containing the originCamera we're updating.
    init(_ arcgisARView: ArcGISARView) {
        self.arcgisARView = arcgisARView

        super.init(frame: .zero)
        
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
            labelView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8.0)
        ])
        
        // Add the heading label and slider.
        let headingLabel = UILabel(frame: .zero)
        headingLabel.text = "Heading"
        headingLabel.textColor = .yellow
        addSubview(headingLabel)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headingLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            headingLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        addSubview(headingSlider)
        headingSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headingSlider.leadingAnchor.constraint(equalTo: headingLabel.trailingAnchor, constant: 16),
            headingSlider.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            headingSlider.centerYAnchor.constraint(equalTo: headingLabel.centerYAnchor)
        ])

        // Add the elevation label and slider.
        elevationLabel.text = "Elevation"
        elevationLabel.textColor = .yellow
        addSubview(elevationLabel)
        elevationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            elevationLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            elevationLabel.bottomAnchor.constraint(equalTo: headingLabel.topAnchor, constant: -24)
        ])

        addSubview(elevationSlider)
        elevationSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            elevationSlider.leadingAnchor.constraint(equalTo: elevationLabel.trailingAnchor, constant: 16),
            elevationSlider.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            elevationSlider.centerYAnchor.constraint(equalTo: elevationLabel.centerYAnchor)
        ])

        // Setup actions for the two sliders. The sliders operate as "joysticks", where moving the slider thumb will start a timer
        // which roates or elevates the current camera when the timer fires.  The elevation and heading delta
        // values increase the further you move away from center.  Moving and holding the thumb a little bit from center
        // will roate/elevate just a little bit, but get progressively more the further from center the thumb is moved.
        headingSlider.addTarget(self, action: #selector(headingChanged(_:)), for: .valueChanged)
        headingSlider.addTarget(self, action: #selector(touchUpHeading(_:)), for: [.touchUpInside, .touchUpOutside])

        elevationSlider.addTarget(self, action: #selector(elevationChanged(_:)), for: .valueChanged)
        elevationSlider.addTarget(self, action: #selector(touchUpElevation(_:)), for: [.touchUpInside, .touchUpOutside])

        elevationSlider.isHidden = !elevationControlVisibility
        elevationLabel.isHidden = !elevationControlVisibility
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If the user tapped in the view (and not in the sliders), do not handle the event.
        // This allows the view below the calibration view to handle touch events.  In this case,
        // that view is the SceneView.
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            return nil
        } else {
            return hitView
        }
    }

    // The timers for the "joystick" behavior.
    private var elevationTimer: Timer?
    private var headingTimer: Timer?
    
    /// Handle an elevation slider value-changed event.
    ///
    /// - Parameter sender: The slider tapped on.
    @objc
    func elevationChanged(_ sender: UISlider) {
        if elevationTimer == nil {
            // Create a timer which elevates the camera when fired.
            elevationTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] (_) in
                let delta = self?.joystickElevation() ?? 0.0
//                print("elevate delta = \(delta)")
                self?.elevate(delta)
            }
            
            // Add the timer to the main run loop.
            guard let timer = elevationTimer else { return }
            RunLoop.main.add(timer, forMode: .default)
        }
    }
    
    /// Handle an heading slider value-changed event.
    ///
    /// - Parameter sender: The slider tapped on.
    @objc
    func headingChanged(_ sender: UISlider) {
        if headingTimer == nil {
            // Create a timer which rotates the camera when fired.
            headingTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] (_) in
                let delta = self?.joystickHeading() ?? 0.0
//                print("rotate delta = \(delta)")
                self?.rotate(delta)
            }
            
            // Add the timer to the main run loop.
            guard let timer = headingTimer else { return }
            RunLoop.main.add(timer, forMode: .default)
        }
    }
    
    /// Handle an elevation slider touchUp event.  This will stop the timer.
    ///
    /// - Parameter sender: The slider tapped on.
    @objc
    func touchUpElevation(_ sender: UISlider) {
        elevationTimer?.invalidate()
        elevationTimer = nil
        sender.value = 0.0
    }
    
    /// Handle a heading slider touchUp event.  This will stop the timer.
    ///
    /// - Parameter sender: The slider tapped on.
    @objc
    func touchUpHeading(_ sender: UISlider) {
        headingTimer?.invalidate()
        headingTimer = nil
        sender.value = 0.0
    }

    /// Rotates the camera by `deltaHeading`.
    ///
    /// - Parameter deltaHeading: The amount to rotate the camera.
    private func rotate(_ deltaHeading: Double) {
        let camera = arcgisARView.originCamera
        let newHeading = camera.heading + deltaHeading
        arcgisARView.originCamera = camera.rotate(toHeading: newHeading, pitch: camera.pitch, roll: camera.roll)
    }
    
    /// Change the cameras altitude by `deltaAltitude`.
    ///
    /// - Parameter deltaAltitude: The amount to elevate the camera.
    private func elevate(_ deltaAltitude: Double) {
        arcgisARView.originCamera = arcgisARView.originCamera.elevate(withDeltaAltitude: deltaAltitude)
    }
    
    /// Calculates the elevation delta amount based on the elevation slider value.
    ///
    /// - Returns: The elevation delta.
    private func joystickElevation() -> Double {
        let deltaElevation = Double(elevationSlider.value)
        return pow(deltaElevation, 2) / 50.0 * (deltaElevation < 0 ? -1.0 : 1.0)
    }
    
    /// Calculates the heading delta amount based on the heading slider value.
    ///
    /// - Returns: The heading delta.
    private func joystickHeading() -> Double {
        let deltaHeading = Double(headingSlider.value)
        return pow(deltaHeading, 2) / 25.0 * (deltaHeading < 0 ? -1.0 : 1.0)
    }
}

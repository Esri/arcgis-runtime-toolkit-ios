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

extension ARCamera.TrackingState {
    var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Tracking unavailable"
        case .limited(.excessiveMotion):
            return "Limited - Excessive Motion"
        case .limited(.insufficientFeatures):
            return "Limited - Insufficient Features"
        case .limited(.initializing):
            return "Limited - Initializing"
        default:
            return ""
        }
    }
}

extension AGSLocationDataSourceStatus {
    var description: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting"
        case .started:
            return "Started"
        case .failedToStart:
            return "Failed to start"
        @unknown default:
            fatalError("Unknown AGSLocationDataSourceStatus")
        }
    }
}

/// A view controller for display AR-related status information.
class ARStatusViewController: UITableViewController {
    @IBOutlet var trackingStateLabel: UILabel!
    @IBOutlet var frameRateLabel: UILabel!
    @IBOutlet var errorDescriptionLabel: UILabel!
    @IBOutlet var sceneLabel: UILabel!
    @IBOutlet var translationFactorLabel: UILabel!
    @IBOutlet var horizontalAccuracyLabel: UILabel!
    @IBOutlet var verticalAccuracyLabel: UILabel!
    @IBOutlet var locationDataSourceStatusLabel: UILabel!

    /// The `ARKit` camera tracking state.
    var trackingState: ARCamera.TrackingState = .notAvailable {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.trackingStateLabel?.text = self.trackingState.description
            }
        }
    }
    
    /// The calculated frame rate of the `SceneView` and `ARKit` display.
    var frameRate: Int = 0 {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.frameRateLabel?.text = "\(self.frameRate) fps"
            }
        }
    }

    /// The current error message.
    var errorMessage: String? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.errorDescriptionLabel?.text = self.errorMessage
            }
        }
    }

    /// The label for the currently selected scene.
    var currentScene: String = "None" {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sceneLabel?.text = self.currentScene
            }
        }
    }

    /// The translation factor applied to the current scene.
    var translationFactor: Double = 1.0 {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.translationFactorLabel?.text = String(format: "%.1f", self.translationFactor)
            }
        }
    }

    /// The horizontal accuracy of the last location.
    var horizontalAccuracyMeasurement = Measurement(value: 1, unit: UnitLength.meters) {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.horizontalAccuracyLabel?.text = self.measurementFormatter.string(from: self.horizontalAccuracyMeasurement)
            }
        }
    }

    /// The vertical accuracy of the last location.
    var verticalAccuracyMeasurement = Measurement(value: 1, unit: UnitLength.meters) {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.verticalAccuracyLabel?.text = self.measurementFormatter.string(from: self.verticalAccuracyMeasurement)
            }
        }
    }

    /// The status of the location data source.
    var locationDataSourceStatus: AGSLocationDataSourceStatus = .stopped {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationDataSourceStatusLabel?.text = self.locationDataSourceStatus.description
            }
        }
    }

    private let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = [.naturalScale, .providedUnit]
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a blur effect behind the table view.
        tableView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    }
}

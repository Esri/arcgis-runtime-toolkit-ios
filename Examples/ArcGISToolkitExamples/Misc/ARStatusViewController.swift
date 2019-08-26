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
    public var trackingState: ARCamera.TrackingState = .notAvailable {
        didSet {
            guard trackingStateLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.trackingStateLabel.text = self.trackingState.description
            }
        }
    }
    
    /// The calculated frame rate of the `SceneView` and `ARKit` display.
    public var frameRate: Int = 0 {
        didSet {
            guard frameRateLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.frameRateLabel.text = "\(self.frameRate)"
            }
        }
    }

    /// The current error message.
    public var errorMessage: String? {
        didSet {
            guard errorDescriptionLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.errorDescriptionLabel.text = self.errorMessage
            }
        }
    }

    /// The label for the currently selected scene.
    public var currentScene: String = "None" {
        didSet {
            guard sceneLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.sceneLabel.text = self.currentScene
            }
        }
    }

    /// The translation factor applied to the current scene.
    public var translationFactor: Double = 1.0 {
        didSet {
            guard translationFactorLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.translationFactorLabel.text = String(format: "%.2f", self.translationFactor)
            }
        }
    }

    /// The horizontal accuracy of the last location.
    public var horizontalAccuracy: Double = 1.0 {
        didSet {
            guard horizontalAccuracyLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.horizontalAccuracyLabel.text = String(format: "%.0f", self.horizontalAccuracy)
            }
        }
    }

    /// The vertical accuracy of the last location.
    public var verticalAccuracy: Double = 1.0 {
        didSet {
            guard verticalAccuracyLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.verticalAccuracyLabel.text = String(format: "%.0f", self.verticalAccuracy)
            }
        }
    }

    /// The status of the location data source.
    public var locationDataSourceStatus: AGSLocationDataSourceStatus = .stopped {
        didSet {
            guard locationDataSourceStatusLabel != nil else { return }
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.locationDataSourceStatusLabel.text = self.locationDataSourceStatus.description
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a blur effect behind the table view.
        tableView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    }
}

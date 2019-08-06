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

/// A view controller for display AR-related status information.
class ARStatusViewController: UITableViewController {

    @IBOutlet var trackingStateLabel: UILabel!
    @IBOutlet var frameRateLabel: UILabel!
    @IBOutlet var errorDescriptionLabel: UILabel!
    @IBOutlet var sceneLabel: UILabel!
    @IBOutlet var translationFactorLabel: UILabel!
    
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
    public var errorMessage: String = "None" {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.errorDescriptionLabel.text = self.errorMessage
            }
        }
    }

    /// The label for the currently selected scene.
    public var currentScene: String = "None" {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.sceneLabel.text = self.currentScene
            }
        }
    }

    /// The translation factor applied to the current scene.
    public var translationFactor: Double = 1.0 {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                guard let self = self else { return }
                self.translationFactorLabel.text = String(format: "%.2f", self.translationFactor)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a blur effect behind the table view.
        tableView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    }
}

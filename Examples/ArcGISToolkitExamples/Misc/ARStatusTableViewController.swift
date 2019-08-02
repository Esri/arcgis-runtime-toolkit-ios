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
class ARStatusTableViewController: UITableViewController {
    
    /// The `ARKit` camera tracking state.
    public var trackingState: ARCamera.TrackingState = .notAvailable {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    /// The calculated frame rate of the `SceneView` and `ARKit` display.
    public var frameRate: Int = 0 {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    /// The current error message.
    public var errorMessage: String = "None" {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                self?.tableView.reloadData()
            }
        }
    }

    /// The label for the currently selected scene.
    public var currentScene: String = "None" {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    /// The translation factor applied to the current scene.
    public var translationFactor: Double = 1.0 {
        didSet {
            DispatchQueue.main.async{ [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    
    /// The labels for each status item.
    private let cellLabels = ["Tracking State", "Frame Rate", "Error", "Scene", "Translation Factor"]
    
    /// The height of our rows.
    private let rowHeight: CGFloat = 24.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the rowHeight of our table view.
        tableView.rowHeight = rowHeight
        
        // Add a blur effect behind the table view.
        tableView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    }
    
    /// Calculates and returns the height of the table view based on the row height and number of rows.
    ///
    /// - Returns: The calculated height of the table view.
    public func height() -> CGFloat {
        return CGFloat(cellLabels.count) * rowHeight
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 0) ? cellLabels.count : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Don't reuse cells, as our table is essentially static.
        let statusCell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        statusCell.backgroundColor = .clear
        statusCell.textLabel?.font = UIFont.systemFont(ofSize: 12.0)
        statusCell.detailTextLabel?.font = UIFont.boldSystemFont(ofSize: 12.0)
        statusCell.detailTextLabel?.textColor = .black
        
        statusCell.textLabel?.text = cellLabels[indexPath.row]
        
        var detailString = ""
        switch indexPath.row {
        case 0:
            detailString = trackingState.description
        case 1:
            detailString = "\(self.frameRate)"
        case 2:
            detailString = errorMessage
        case 3:
            detailString = currentScene
        case 4:
            detailString = String(format: "%.2f", self.translationFactor)
        default:
            detailString = ""
        }
        statusCell.detailTextLabel?.text = detailString
        
        return statusCell
    }
}

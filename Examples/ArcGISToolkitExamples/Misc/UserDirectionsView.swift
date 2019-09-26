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

/// A custom view for dislaying directions to the user.
class UserDirectionsView: UIVisualEffectView {
    private let userDirectionsLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24.0)
        label.textColor = .darkText
        label.numberOfLines = 0
        label.text = "Initializing ARKit..."
        return label
    }()

    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        
        // Set a corner radius.
        layer.cornerRadius = 8.0
        layer.masksToBounds = true
        
        contentView.addSubview(userDirectionsLabel)
        userDirectionsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userDirectionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            userDirectionsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            userDirectionsLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            userDirectionsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Updates the displayed user directions string.  If `message` is nil or empty, this will hide the view.  If `message` is not empty, it will display the view.
    ///
    /// - Parameter message: the new string to display.
    func updateUserDirections(_ message: String?) {
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.alpha = (message?.isEmpty ?? true) ? 0.0 : 1.0
            self?.userDirectionsLabel.text = message
        }
    }
}

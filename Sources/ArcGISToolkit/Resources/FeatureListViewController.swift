// Copyright 2022 Esri.

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

open class FeatureListViewController: UITableViewController {
    public var popups = [AGSPopup]()
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return popups.count
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = popups[indexPath.row].geoElement.geometry?.description.isEmpty ?? true ? "some popup" : popups[indexPath.row].geoElement.geometry?.description
        return cell
    }
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let containerStyle: AGSPopupsViewControllerContainerStyle = .navigationController// : .navigationBar
        
        let singlePopup = popups[indexPath.row]
        let popupsViewController = AGSPopupsViewController(popups: [singlePopup], containerStyle: containerStyle)
        popupsViewController.geometryEditingStyle = .toolbar
        popupsViewController.customDoneButton = nil
//        popupsViewController.delegate = self
        
        if containerStyle == .navigationController {
            // set a back button for the pvc in the nav controller, showing modally, this is handled for us
            // need to do this so we can clean up (unselect feature, etc) when `back` is tapped
            let doneViewingBbi = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(doneViewingInNavController))
            popupsViewController.customDoneButton = doneViewingBbi
            popupsViewController.navigationItem.leftBarButtonItem = doneViewingBbi
            
            navigationController?.pushViewController(popupsViewController, animated: true)
        } else {
            present(popupsViewController, animated: true)
        }
        
//        if let vc = vcOpt {
//            navigationController?.pushViewController(vc, animated: true)
//        }
    }
    
    @objc
    private func doneViewingInNavController() {
        navigationController?.popViewController(animated: true)
    }
}

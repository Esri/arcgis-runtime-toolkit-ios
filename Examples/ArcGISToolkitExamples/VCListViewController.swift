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
import ArcGISToolkit

open class VCListViewController: UITableViewController {
    public var storyboardName: String?
    
    public var viewControllerInfos: [(vcName: String, viewControllerType: UIViewController.Type, nibName: String?)] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewControllerInfos.count
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = viewControllerInfos[indexPath.row].vcName
        return cell
    }
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let t = viewControllerInfos[indexPath.row].viewControllerType
        let nibName = viewControllerInfos[indexPath.row].nibName
        var vcOpt: UIViewController?
        
        // first check storyboard
        if let storyboardName = self.storyboardName {
            let sb = UIStoryboard(name: storyboardName, bundle: nil)
            if let nibName = nibName {
                // this is how you can check to see if that identifier is in the nib, based on http://stackoverflow.com/a/34650505/1687195
                if let dictionary = sb.value(forKey: "identifierToNibNameMap") as? NSDictionary {
                    if dictionary.value(forKey: nibName) != nil {
                        vcOpt = sb.instantiateViewController(withIdentifier: nibName)
                    }
                }
            }
        }
        
        if vcOpt == nil {
            vcOpt = t.init(nibName: nibName, bundle: nil)
        }
        
        if let vc = vcOpt {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

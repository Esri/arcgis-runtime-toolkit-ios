// Copyright 2016 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

import ArcGIS

extension UITableViewCell{
    
    func setPortalItem(_ portalItem: AGSPortalItem, for indexPath: IndexPath){
        
        // tag the cell so we know what index path it's being used for
        self.tag = indexPath.hashValue
        
        // set title
        self.textLabel?.text = portalItem.title
        
        //
        // Set the image of a UITableViewCell to the portal item's thumbnail
        // Set the thumbnail on cell.imageView?.image
        //   - The thumbnail property of the AGSPortalItem implements AGSLoadable, which means
        //     that you have to call loadWithCompletion on it to get it's value
        //   - use the cell's tag to make sure that once you get the thumbnail, that cell is
        //     still being used for the indexPath.row that you care about
        //     (cells can get recycled by the time the thumbnail comes in)
        //   - once you set the image on cell.imageView?.image, you will need to call cell.setNeedsLayout() for it to appear
        
        // set thumbnail on cell
        self.imageView?.image = portalItem.thumbnail?.image
        // if imageview is still nil then need to load the thumbnail
        if self.imageView?.image == nil {
            
            // set default image until thumb is loaded
            self.imageView?.image = UIImage(named: "placeholder")
            // have to call setNeedsLayout for image to draw
            self.setNeedsLayout()
            
            portalItem.thumbnail?.load() { [weak portalItem, weak self] (error) in
                
                guard let strongSelf = self, let portalItem = portalItem else{
                    return
                }
                
                // make sure this is the cell we still care about and that it
                // wasn't already recycled by the time we get the thumbnail
                if strongSelf.tag != indexPath.hashValue{
                    return
                }
                
                // now if no error then set the thumbnail image
                // reload the cell
                if error == nil {
                    strongSelf.imageView?.image = portalItem.thumbnail?.image
                    // have to call setNeedsLayout for image to draw
                    strongSelf.setNeedsLayout()
                }
            }
        }
    }
    
}


extension UIApplication {
    func topViewController(_ controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(presented)
        }
        return controller
    }
}



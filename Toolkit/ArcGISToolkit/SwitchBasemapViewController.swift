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

import UIKit
import ArcGIS

public class SwitchBasemapViewController: TableViewController {
    
    // basemap array for listing in tableview
    var basemaps = [AGSBasemap]()
    
    var map: AGSMap?
    
    public init(map: AGSMap){
        self.map = map
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Basemaps"
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        if basemaps.isEmpty{
            loadInitialData()
        }
    }
    
    func loadInitialData(){
    
        // if map has a portal item then fetch portal basemaps
        if let pi = map?.item as? AGSPortalItem{
            pi.portal.fetchBasemaps {
                [weak self] (results, error) in
                
                if let results = results{
                    // set our basemaps array and reload tableview
                    //
                    self?.basemaps = results
                    self?.tableView.reloadData()
                }
                else if let error = error{
                    // show the user an error occurred
                    //

                    let alert = UIAlertController(title: "Error Fetching Basemaps", message: error.localizedDescription, preferredStyle: .alert)
                    let ok = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(ok)
                    
                    self?.present(alert, animated: true, completion: nil)
                    
                }
            }
        }
        else{
            // otherwise we just show a list of some common basemaps
            
            basemaps = [AGSBasemap.streetsVector(),
                      AGSBasemap.navigationVector(),
                      AGSBasemap.topographicVector(),
                      AGSBasemap.streetsNightVector(),
                      AGSBasemap.darkGrayCanvasVector(),
                      AGSBasemap.lightGrayCanvasVector(),
                      AGSBasemap.imageryWithLabelsVector(),
                      AGSBasemap.streetsWithReliefVector(),
                      AGSBasemap.terrainWithLabelsVector()]
            
            self.tableView.reloadData()
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        // when the user taps on a basemap
        // switch the basemap of the map and goBack
        //
        map?.basemap = self.basemaps[(indexPath as NSIndexPath).row]
        self.goBack(nil)
    }
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return basemaps.count
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)!
        let basemap = self.basemaps[(indexPath as NSIndexPath).row]
        
        if let pi = basemap.item as? AGSPortalItem{
            // if we have a portal item for the basemap, use that
            cell.setPortalItem(pi, for: indexPath)
        }
        else{
            // otherwise just show the basemap name
            cell.textLabel?.text = basemap.name
        }
        return cell
    }
    
    func cancelAction(_ sender: AnyObject) {
        self.goBack(nil)
    }
}






//
//  LayerContentsTableViewController.swift
//  ArcGISToolkit
//
//  Created by Mark Dostal on 11/19/19.
//  Copyright © 2019 Esri. All rights reserved.
//

import UIKit
import ArcGIS

class LegendInfoCell: UITableViewCell {
    @IBOutlet var name : UILabel?
    @IBOutlet var legendImageView : UIImageView?
    @IBOutlet var activityIndicatorView : UIActivityIndicatorView?
}

class LayerTitleCell: UITableViewCell {
    @IBOutlet var name : UILabel?
}

class SublayerTitleCell: UITableViewCell {
    @IBOutlet var name : UILabel?
}

class LayerContentsTableViewController: UITableViewController {
    var legendInfoCellReuseIdentifier = "LegendInfo"
    var layerCellReuseIdentifier = "LayerTitle"
    var sublayerCellReuseIdentifier = "SublayerTitle"

    var geoView: AGSGeoView?

    var layerContents = [AGSLayerContent]()

    var config: Configuration = LayerContentsViewController.TableOfContents()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, take into account configuration
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, take into account configuration
        return layerContents.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: layerCellReuseIdentifier, for: indexPath) as! LayerTitleCell

        // Configure the cell...
        cell.name?.text = layerContents[indexPath.row].name
        
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}

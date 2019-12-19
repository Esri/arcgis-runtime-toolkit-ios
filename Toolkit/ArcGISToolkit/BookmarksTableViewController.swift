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
import ArcGIS

class BookmarksTableViewController: UITableViewController {
    var bookmarks = [AGSBookmark]() {
        didSet {
            if let indexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: indexPath, animated: false)
            }
            tableView.reloadData()
        }
    }
    
    weak var delegate: BookmarksViewControllerDelegate?
    
    private var cellReuseIdentifier = "cell"
    
    // Private property to store selection action for table cell.
    private var selectAction: ((AGSBookmark) -> Void)?
    
    // Executed for tableview row selection.
    func setSelectAction(_ action : @escaping ((AGSBookmark) -> Void)) {
        self.selectAction = action
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.text = bookmarks[indexPath.row].name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectAction?(bookmarks[indexPath.row])
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

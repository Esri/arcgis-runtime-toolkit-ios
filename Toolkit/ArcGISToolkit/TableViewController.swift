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

open class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    public var cellReuseIdentifier = "cell"
    public var tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        view.addSubview(tableView)
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
    
    public func goBack(_ completion: (()->Void)? ){
        if let nc = navigationController{
            nc.popViewController(animated: true)
            completion?()
        }
        else{
            self.dismiss(animated: true){
                completion?()
            }
        }
    }
}

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
import ArcGIS
import ArcGISToolkit
import UserNotifications

// NOTE:
//
// The JobManagerExample allows you to kick off some jobs, kill the application,
// restart the application, and find out what jobs were running and have the ability to
// resume them.
//

class JobTableViewCell: UITableViewCell {
    var job: AGSJob?
    var observation: NSKeyValueObservation?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureWithJob(job: AGSJob?) {
        // invalidate previous observation
        observation?.invalidate()
        observation = nil
        
        self.job = job
        
        self.updateUI()
        
        // observe job
        observation = self.job?.progress.observe(\.fractionCompleted) { [weak self] (_, _) in
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }
    }
    
    func updateUI() {
        guard let job = job else {
            return
        }
        
        let title = "\(JobTableViewCell.jobTypeString(job)) Job: \(job.status.asString())"
        
        self.textLabel?.text = title
        self.detailTextLabel?.text = job.messages.last?.message
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = ""
        self.detailTextLabel?.text = ""
    }
    
    class func jobTypeString(_ job: AGSJob) -> String {
        if job is AGSGenerateGeodatabaseJob {
            return "Generate GDB"
        } else if job is AGSSyncGeodatabaseJob {
            return "Sync GDB"
        } else if job is AGSExportTileCacheJob {
            return "Export Tiles"
        } else if job is AGSEstimateTileCacheSizeJob {
            return "Estimate Tile Cache Size"
        } else if job is AGSGenerateOfflineMapJob {
            return "Offline Map"
        } else if job is AGSOfflineMapSyncJob {
            return "Offline Map Sync"
        } else if job is AGSGeoprocessingJob {
            return "Geoprocessing"
        } else if job is AGSExportVectorTilesJob {
            return "Export Vector Tiles"
        } else if job is AGSDownloadPreplannedOfflineMapJob {
            return "Download Preplanned Offline Map"
        }
        return "Other"
    }
}

class JobManagerExample: TableViewController {
    // array to hold onto tasks while they are loading
    var tasks = [AGSGeodatabaseSyncTask]()
    
    var jobs: [AGSJob] {
        return JobManager.shared.jobs
    }
    
    var backgroundTaskIdentifiers = Set<UIBackgroundTaskIdentifier>()
    
    var toolbar: UIToolbar?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a Toolbar and add it to the view controller
        let toolbar = UIToolbar()
        self.toolbar = toolbar
        let toolbarHeight: CGFloat = 44.0
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight).isActive = true
        
        // move safe area up above toolbar
        // (this adjusts tableview contentInsets to correctly scroll behind toolbar)
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: toolbarHeight, right: 0)
        // now anchor toolbar below new safe area
        toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        
        // request authorization for user notifications, this way we can notify user in bg when job complete
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, _) in
            if !granted {
                print("You must grant access for user notifications for all the features of this sample to work")
            }
        }
        
        // job cell registration
        tableView.register(JobTableViewCell.self, forCellReuseIdentifier: "JobCell")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // resume any paused jobs when this view controller is shown
        JobManager.shared.resumeAllPausedJobs(
            statusHandler: { [weak self] in
                self?.jobStatusHandler(status: $0)
            },
            completion: { [weak self] in
                self?.jobCompletionHandler(result: $0, error: $1)
            }
        )
        
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // When the view controller is popped, we pause all running jobs.
        // In a normal app you would not need to do this, but this view controller
        // is acting as an app example. Thus when it is not being shown, we pause
        // the jobs so that when the view controller is re-shown we can resume and rewire
        // the handlers up to them. Otherwise we would have no way to hook into the status
        // of any currently running jobs. A normal app would not likely need this as it would
        // have an object globally wiring up status and completion handlers to jobs.
        // But since this sample view controller can be pushed/pop, we need this.
        JobManager.shared.pauseAllJobs()
        
        // clear out background tasks that we started for the jobs
        backgroundTaskIdentifiers.forEach { UIApplication.shared.endBackgroundTask($0) }
        backgroundTaskIdentifiers.removeAll()
        
        super.viewWillDisappear(animated)
    }
    
    deinit {
        // clear out background tasks that we started for the jobs
        backgroundTaskIdentifiers.forEach { UIApplication.shared.endBackgroundTask($0) }
    }
    
    func startBackgroundTask() -> UIBackgroundTaskIdentifier {
        var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
        backgroundTaskIdentifiers.insert(backgroundTaskIdentifier)
        return backgroundTaskIdentifier
    }
    
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        UIApplication.shared.endBackgroundTask(identifier)
        backgroundTaskIdentifiers.remove(identifier)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let toolbar = toolbar, toolbar.items == nil {
            // button to kick off a new job
            let kickOffJobItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(kickOffJob))
            
            // button to clear the finished jobs
            let clearFinishedJobsItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearFinishedJobs))
            
            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbar.items = [kickOffJobItem, flexibleSpace, clearFinishedJobsItem]
        }
    }
    
    @objc
    func clearFinishedJobs() {
        JobManager.shared.clearFinishedJobs()
        tableView.reloadData()
    }
    
    var i = 0
    
    @objc
    func kickOffJob() {
        if (i % 2) == 0 {
            let url = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer")!
            generateGDB(URL: url, syncModel: .layer, extent: nil)
        } else {
            let portalItem = AGSPortalItem(url: URL(string: "https://www.arcgis.com/home/item.html?id=acc027394bc84c2fb04d1ed317aac674")!)!
            let map = AGSMap(item: portalItem)
            // naperville
            let env = AGSEnvelope(xMin: -9813416.487598, yMin: 5126112.596989, xMax: -9812775.435463, yMax: 5127101.526749, spatialReference: AGSSpatialReference.webMercator())
            takeOffline(map: map, extent: env)
        }
        
        i += 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return jobs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "JobCell") as! JobTableViewCell
        let job = jobs[indexPath.row]
        cell.configureWithJob(job: job)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    var documentsPath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    func generateGDB(URL: URL, syncModel: AGSSyncModel, extent: AGSEnvelope?) {
        // try to keep the app running in the background for this job if possible
        let backgroundTaskIdentifier = self.startBackgroundTask()
        
        let task = AGSGeodatabaseSyncTask(url: URL)
        
        // hold on to task so that it stays retained while it's loading
        self.tasks.append(task)
        
        task.load { [weak self, weak task] error in
            // make sure we are still around...
            guard let self = self, let strongTask = task else {
                // don't need to end the background task here as that
                // would have been done in deinit
                return
            }
            
            // remove task from array now that it's loaded
            if let index = self.tasks.firstIndex(where: { return $0 === strongTask }) {
                self.tasks.remove(at: index)
            }
            
            // return if error or no featureServiceInfo
            guard error == nil, let fsi = strongTask.featureServiceInfo else {
                self.endBackgroundTask(backgroundTaskIdentifier)
                return
            }
            
            let params = AGSGenerateGeodatabaseParameters()
            
            params.extent = extent
            if params.extent == nil {
                params.extent = fsi.fullExtent
            }
            
            params.outSpatialReference = AGSSpatialReference.webMercator()
            
            if syncModel == .geodatabase {
                params.syncModel = .geodatabase
            } else {
                params.syncModel = .layer
                var options = [AGSGenerateLayerOption]()
                for li in fsi.layerInfos {
                    let option = AGSGenerateLayerOption(layerID: li.id)
                    options.append(option)
                }
                params.layerOptions = options
            }
            
            let uuid = NSUUID()
            let downloadURL = NSURL(fileURLWithPath: "\(self.documentsPath)/\(uuid.uuidString).geodatabase") as URL
            
            // create a job
            let job = strongTask.generateJob(with: params, downloadFileURL: downloadURL)
            
            // register the job with our JobManager shared instance
            JobManager.shared.register(job: job)
            
            // start the job
            job.start(
                statusHandler: { [weak self] in
                    self?.jobStatusHandler(status: $0)
                },
                completion: { [weak self] in
                    self?.jobCompletionHandler(result: $0, error: $1)
                    self?.endBackgroundTask(backgroundTaskIdentifier)
                }
            )
            
            // refresh the tableview
            self.tableView.reloadData()
        }
    }
    
    func takeOffline(map: AGSMap, extent: AGSEnvelope) {
        // try to keep the app running in the background for this job if possible
        let backgroundTaskIdentifier = self.startBackgroundTask()
        
        let task = AGSOfflineMapTask(onlineMap: map)
        
        let uuid = NSUUID()
        let offlineMapURL = URL(fileURLWithPath: "\(self.documentsPath)/\(uuid.uuidString)") as URL
        
        task.defaultGenerateOfflineMapParameters(withAreaOfInterest: extent) { [weak self] params, error in
            // make sure we are still around...
            guard let self = self else {
                // don't need to end the background task here as that
                // would have been done in deinit
                return
            }
            
            if let params = params {
                let job = task.generateOfflineMapJob(with: params, downloadDirectory: offlineMapURL)
                
                // register the job with our JobManager shared instance
                JobManager.shared.register(job: job)
                
                // start the job
                job.start(
                    statusHandler: { [weak self] in
                        self?.jobStatusHandler(status: $0)
                    },
                    completion: { [weak self] in
                        self?.jobCompletionHandler(result: $0, error: $1)
                        self?.endBackgroundTask(backgroundTaskIdentifier)
                    }
                )
                
                // refresh the tableview
                self.tableView.reloadData()
            } else {
                // if could not get default parameters, then fire completion with the error
                self.jobCompletionHandler(result: nil, error: error)
                self.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
    }
    func jobStatusHandler(status: AGSJobStatus) {
        print("status: \(status.asString())")
    }
    
    func jobCompletionHandler(result: Any?, error: Error?) {
        print("job completed")
        
        if let error = error {
            print("  - error: \(error)")
        } else if let result = result {
            print("  - result: \(result)")
        }
        
        let content = UNMutableNotificationContent()
        content.body = "Job Complete"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "job complete", content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request)
    }
}

extension AGSJobStatus {
    func asString() -> String {
        switch self {
        case .failed:
            return "Failed"
        case .notStarted:
            return "Not Started"
        case .paused:
            return "Paused"
        case .succeeded:
            return "Succeeded"
        case .started:
            return "Started"
        @unknown default:
            fatalError("Unknown AGSJobStatus")
        }
    }
}

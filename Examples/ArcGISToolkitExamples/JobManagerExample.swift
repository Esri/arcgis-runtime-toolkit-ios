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

// NOTE:
// 
// The JobManagerExample allows you to kick off some jobs, kill the application,
// restart the application, and find out what jobs were running and have the ability to
// resume them.
//
// The other aspect of this sample is that if you just background the app then it will
// provide a helper method that helps with background fetch.
//
// See the AppDelegate.swift for implementation of the function:
// `func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)`
// We forward that call to the shared JobManager so that it can perform the background fetch.
//

class JobTableViewCell: UITableViewCell{
    
    var job : AGSJob?
    private var observerContext = 0
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureWithJob(job: AGSJob?){
        
        // remove previous observer
        self.job?.removeObserver(self, forKeyPath: #keyPath(AGSJob.status))
        
        self.job = job
        
        self.updateUI()
        
        // add observer
        self.job?.addObserver(self, forKeyPath: #keyPath(AGSJob.status), options: .new, context: &observerContext)
    }
    
    func updateUI(){
        
        guard let job = job else{
            return
        }
        
        let title = "\(JobTableViewCell.jobTypeString(job)) Job: \(job.status.asString())"
        
        self.textLabel?.text = title
        self.detailTextLabel?.text = job.messages.last?.message
    }
    
    override func prepareForReuse() {
        self.textLabel?.text = ""
        self.detailTextLabel?.text = ""
    }
    
    
    class func jobTypeString(_ job: AGSJob)->String{
        if job is AGSGenerateGeodatabaseJob{
            return "Generate GDB"
        }
        else if job is AGSSyncGeodatabaseJob{
            return "Sync GDB"
        }
        else if job is AGSExportTileCacheJob{
            return "Export Tiles"
        }
        else if job is AGSEstimateTileCacheSizeJob{
            return "Estimate Tile Cache Size"
        }
        else if job is AGSGenerateOfflineMapJob{
            return "Offline Map"
        }
        else if job is AGSOfflineMapSyncJob{
            return "Offline Map Sync"
        }
        else if job is AGSGeoprocessingJob{
            return "Geoprocessing"
        }
        else if job is AGSExportVectorTilesJob{
            return "Export Vector Tiles"
        }
        else if job is AGSDownloadPreplannedOfflineMapJob{
            return "Download Preplanned Offline Map"
        }
        return "Other"
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        
        if context != &observerContext{
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(AGSJob.status) {
            self.updateUI()
        }
    }
    
}

class JobManagerExample: TableViewController {
    
    // array to hold onto tasks while they are loading
    var tasks = [AGSGeodatabaseSyncTask]()
    
    var jobs : [AGSJob] {
        return JobManager.shared.jobs
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        let toolbarFrame = CGRect(x: 0, y: view.bounds.size.height - 44.0, width: view.bounds.size.width, height: 44.0)
        
        // create a Toolbar and add it to the view controller
        let toolbar = UIToolbar()
        toolbar.frame = toolbarFrame
        toolbar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(toolbar)
        
        // button to kick off a new job
        let kickOffJobItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(kickOffJob))
        
        // button to resume all paused jobs
        // use this to resume the paused jobs you have after restarting your app
        let resumeAllPausedJobsItem = UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(resumeAllPausedJobs))
        
        // button to clear the finished jobs
        let clearFinishedJobsItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearFinishedJobs))
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [kickOffJobItem, flex, resumeAllPausedJobsItem, flex, clearFinishedJobsItem]
        
        //
        // register for user notifications, this way we can notify user in bg when job complete
        let notificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        UIApplication.shared.registerUserNotificationSettings(notificationSettings)
        
        // job cell registration
        tableView.register(JobTableViewCell.self, forCellReuseIdentifier: "JobCell")
    }
    
    func resumeAllPausedJobs(){
        JobManager.shared.resumeAllPausedJobs(statusHandler: self.jobStatusHandler, completion: self.jobCompletionHandler)
    }
    
    func clearFinishedJobs(){
        JobManager.shared.clearFinishedJobs()
        tableView.reloadData()
    }
    
    var i = 0
    
    func kickOffJob(){
        
        if (i % 2) == 0{
            let url = URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer")!
            generateGDB(URL: url, syncModel: .layer, extent: nil)
        }
        else{

            let portalItem = AGSPortalItem(url: URL(string:"https://www.arcgis.com/home/item.html?id=acc027394bc84c2fb04d1ed317aac674")!)!
            let map = AGSMap(item: portalItem)
            // naperville
            let env = AGSEnvelope(xMin: -9825684.031125, yMin: 5102237.935062, xMax: -9798254.961608, yMax: 5151000.725314, spatialReference: AGSSpatialReference.webMercator())
            takeOffline(map: map, extent: env)
        }
        
        i += 1
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return jobs.count
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "JobCell") as! JobTableViewCell
        let job = jobs[indexPath.row]
        cell.configureWithJob(job: job)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    var documentsPath: String{
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    func generateGDB(URL: URL, syncModel: AGSSyncModel, extent: AGSEnvelope?){
        
        let task = AGSGeodatabaseSyncTask(url: URL)
        
        // hold on to task so that it stays retained while it's loading
        self.tasks.append(task)
        
        task.load{ [weak self, weak task] error in

            // make sure we are still around...
            guard let strongSelf = self else {
                return
            }
            
            guard let strongTask = task else{
                return
            }
            
            // remove task from array now that it's loaded
            if let index = strongSelf.tasks.index(where: {return $0 === strongTask}){
                strongSelf.tasks.remove(at: index)
            }
            
            // return if error or no featureServiceInfo
            guard error == nil else{
                return
            }
            
            guard let fsi = strongTask.featureServiceInfo else{
                return
            }
            
            let params = AGSGenerateGeodatabaseParameters()
            
            params.extent = extent
            if params.extent == nil{
                params.extent = fsi.fullExtent
            }
            
            params.outSpatialReference = AGSSpatialReference.webMercator()
            
            if syncModel == .geodatabase{
                params.syncModel = .geodatabase
            }
            else{
                params.syncModel = .layer
                var options = [AGSGenerateLayerOption]()
                for li in fsi.layerInfos{
                    let option = AGSGenerateLayerOption(layerID: li.id)
                    options.append(option)
                }
                params.layerOptions = options
            }
            
            let uuid = NSUUID()
            let downloadURL = NSURL(fileURLWithPath: "\(strongSelf.documentsPath)/\(uuid.uuidString).geodatabase") as URL
            
            // create a job
            let job = strongTask.generateJob(with: params, downloadFileURL: downloadURL)
            
            // register the job with our JobManager shared instance
            JobManager.shared.register(job: job)
            
            // start the job
            job.start(statusHandler: strongSelf.jobStatusHandler, completion: strongSelf.jobCompletionHandler)
            
            // refresh the tableview
            strongSelf.tableView.reloadData()
        }
    }
    
    func takeOffline(map: AGSMap, extent: AGSEnvelope){
        
        let task = AGSOfflineMapTask(onlineMap: map)
        
        let uuid = NSUUID()
        let offlineMapURL = URL(fileURLWithPath: "\(self.documentsPath)/\(uuid.uuidString)") as URL
        
        task.defaultGenerateOfflineMapParameters(withAreaOfInterest: extent){ [weak self] params, error in
            
            // make sure we are still around...
            guard let strongSelf = self else {
                return
            }
            
            if let params = params{
                let job = task.generateOfflineMapJob(with: params, downloadDirectory: offlineMapURL)
                
                // register the job with our JobManager shared instance
                JobManager.shared.register(job: job)
                
                // start the job
                job.start(statusHandler: strongSelf.jobStatusHandler, completion: strongSelf.jobCompletionHandler)
                
                // refresh the tableview
                strongSelf.tableView.reloadData()
            }
            else{
                // if could not get default parameters, then fire completion with the error
                strongSelf.jobCompletionHandler(result: nil, error: error)
            }
        }
        
    }
    func jobStatusHandler(status: AGSJobStatus){
        print("status: \(status.asString())")
    }
    
    func jobCompletionHandler(result: Any?, error: Error?){
        print("job completed")
        if let error = error{
            print("  - error: \(error)")
        }
        else if let result = result{
            print("  - result: \(result)")
        }
        
        // make sure we can post a local notification
        guard let settings = UIApplication.shared.currentUserNotificationSettings, settings.types != .none else{
            return
        }
        
        // post local notification letting user know that job is done
        let notification = UILocalNotification()
        notification.fireDate = Date()
        notification.alertBody = "Job Complete"
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.shared.scheduleLocalNotification(notification)
    }
}


extension AGSJobStatus{
    func asString() -> String{
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
        }
    }
}


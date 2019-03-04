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

import ArcGIS
import Foundation

internal typealias JSONDictionary = [String: Any]
public typealias JobStatusHandler = (AGSJobStatus) -> Void
public typealias JobCompletionHandler = (Any?, Error?) -> Void

//
// MARK: JobManager


private let _jobManagerSharedInstance = JobManager(jobManagerID: "shared")

/**
 The JobManager is a class that will manage serializing kicked off Jobs to the NSUserDefaults when the app is backgrounded.
 Then when the JobManager is re-created on launch of an app, it will deserialize the Jobs and provide them for you via it's
 Job's property.
 
 The JobManager works with any AGSJob subclass. Such as AGSSyncGeodatabaseJob, AGSGenerateGeodatabaseJob, AGSExportTileCacheJob, AGSEstimateTileCacheSizeJob, AGSGenerateOfflineMapJob, AGSOfflineMapSyncJob, etc.
 
 Use the shared instance of the JobManager, or create your own with a unique ID. When you kick off a Job, register it with the JobManager.
 
 For supporting background fetch you can forward the call from your AppDelegate's
 `func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping` 
 function, to the same function in this class.
 
 method.
 */
public class JobManager: NSObject {
    
    /// Default shared instance of the JobManager.
    public class var shared: JobManager {
        return _jobManagerSharedInstance
    }
    
    public private(set) var jobManagerID: String
    
    // Flag to signify that we shouldn't write to defaults
    // Maybe we are currently reading from the defaults so it's pointless to write to them.
    // Or maybe we are waiting until a group of modifications are made before writing to the defaults.
    private var suppressSaveToUserDefaults = false
    
    private var kvoContext = 0
    
    deinit {
        jobs.forEach { unObserveJobStatus(job: $0) }
    }
    
    public private(set) var keyedJobs = [String: AGSJob](){
        didSet{
            self.updateJobsArray()
            saveJobsToUserDefaults()
        }
    }
    public private(set) var jobs = [AGSJob]()
    private func updateJobsArray(){
        
        // when our jobs array changes we need to observe the jobs' status
        // that we aren't currently observing. The best way to do that is to
        // just unObserve all, then re-observe all job status events
        
        // so first un-observe all current jobs
        jobs.forEach { unObserveJobStatus(job: $0) }
        
        // set new jobs array
        jobs = keyedJobs.map{ $0.1 }
        
        // now observe all jobs
        jobs.forEach { observeJobStatus(job: $0) }
    }
    
    private func toJSON() -> JSONDictionary{
        var d = [String: Any]()
        for (jobID, job) in self.keyedJobs{
            if let json = try? job.toJSON(){
                d[jobID] = json
            }
        }
        return d
    }
    
    /// Create a JobManager with an ID.
    public required init(jobManagerID: String){
        self.jobManagerID = jobManagerID
        super.init()
        if let d = UserDefaults.standard.dictionary(forKey: self.jobsDefaultsKey){
            suppressSaveToUserDefaults = true
            self.instantiateStateFromJSON(json: d)
            suppressSaveToUserDefaults = false
        }
    }
    
    private func instantiateStateFromJSON(json: JSONDictionary){
        for (jobID, value) in json{
            if let jobJSON = value as? JSONDictionary{
                if let job = (try? AGSJob.fromJSON(jobJSON)) as? AGSJob{
                    self.keyedJobs[jobID] = job
                }
            }
        }
    }
    
    private var jobsDefaultsKey: String {
        return "com.esri.arcgis.runtime.toolkit.jobManager.\(jobManagerID).jobs"
    }
    
    // observing job status code
    
    private func observeJobStatus(job: AGSJob){
        job.addObserver(self, forKeyPath: #keyPath(AGSJob.status), options: [], context: &kvoContext)
    }
    private func unObserveJobStatus(job: AGSJob){
        job.removeObserver(self, forKeyPath: #keyPath(AGSJob.status))
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext{
            if keyPath == #keyPath(AGSJob.status){
                // when a job's status changes we need to save to user defaults again
                // so that the correct job state is reflected in our saved state
                saveJobsToUserDefaults()
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    /**
     Register a Job with the JobManager.
     Returns a uniqueID for the Job.
     */
    @discardableResult public func register(job: AGSJob) -> String{
        let jobUniqueID = NSUUID().uuidString
        keyedJobs[jobUniqueID] = job
        return jobUniqueID
    }

    /**
     Unregister a Job with the JobManager
     Returns true if it found the Job and was able to unregister it.
     */
    @discardableResult public func unregister(job: AGSJob) -> Bool{
        for (key, value) in keyedJobs{
            if value === job{
                keyedJobs.removeValue(forKey: key)
                return true
            }
        }
        return false
    }
    
    /**
     Unregister a Job with the JobManager, using the Job's unique ID.
     Returns true if it found the Job and was able to unregister it.
     */
    @discardableResult public func unregister(jobUniqueID: String) -> Bool{
        let removed = keyedJobs.removeValue(forKey: jobUniqueID) != nil
        return removed
    }
    
    /// Clears the finished Jobs from the Job manager.
    public func clearFinishedJobs(){
        
        suppressSaveToUserDefaults = true
        for (jobUniqueID, job) in keyedJobs{
            if job.status == .failed || job.status == .succeeded{
                keyedJobs.removeValue(forKey: jobUniqueID)
            }
        }
        suppressSaveToUserDefaults = false
        saveJobsToUserDefaults()
        
    }
    
    /**
     Checks the status for all Jobs and returns when completed.
     */
    @discardableResult public func checkStatusForAllJobs(completion: @escaping (Bool)->Void) -> AGSCancelable{
        
        
        let cancelGroup = CancelGroup()
        
        let group = DispatchGroup()
        
        var completedWithoutErrors = true
        
        keyedJobs.forEach{
            group.enter()
            let cancellable = $0.1.checkStatus{ error in
                if error != nil{
                    completedWithoutErrors = false
                }
                group.leave()
            }
            cancelGroup.children.append(cancellable)
        }
        
        group.notify(queue: DispatchQueue.main){
            completion(completedWithoutErrors)
        }
        
        return cancelGroup
    }
    
    /**
     Checks the status for all Jobs and calls the completion handler when done.
     this method can be called from:
     `func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping`
     */
    public func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if self.jobs.count > 0{
            self.checkStatusForAllJobs{ completedWithoutErrors in
                if completedWithoutErrors{
                    completionHandler(.newData)
                }
                else{
                    completionHandler(.failed)
                }
            }
        }
        else{
            completionHandler(.noData)
        }
    }

    
    /// Resume all paused and not-started jobs.
    public func resumeAllPausedJobs(statusHandler: @escaping JobStatusHandler, completion: @escaping JobCompletionHandler){
        keyedJobs.filter{ $0.1.status == .paused || $0.1.status == .notStarted}.forEach{
            $0.1.start(statusHandler: statusHandler, completion:completion)
        }
    }
    
    /**
     Saves all Jobs to User Defaults.
     This happens automatically when the jobs are registered/unregistered.
     It also happens when job status changes.
     */
    private func saveJobsToUserDefaults(){
        
        if suppressSaveToUserDefaults{
            return
        }
        
        let d = self.toJSON()
        UserDefaults.standard.set(d, forKey: self.jobsDefaultsKey)
    }
}








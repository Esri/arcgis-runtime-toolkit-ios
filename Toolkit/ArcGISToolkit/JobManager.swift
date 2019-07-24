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
    
    public let jobManagerID: String
    
    // Flag to signify that we shouldn't write to defaults
    // Maybe we are currently reading from the defaults so it's pointless to write to them.
    // Or maybe we are waiting until a group of modifications are made before writing to the defaults.
    private var suppressSaveToUserDefaults = false
    
    private var kvoContext = 0
    
    public private(set) var keyedJobs = [String: AGSJob]() {
        willSet {
            // Need `self` because of a Swift bug.
            self.keyedJobs.values.forEach { unObserveJobStatus(job: $0) }
        }
        didSet {
            keyedJobs.values.forEach { observeJobStatus(job: $0) }

            // If there was a change, then re-store the serialized jobs in UserDefaults
            if keyedJobs != oldValue {
                saveJobsToUserDefaults()
            }
        }
    }

    public var jobs: [AGSJob] {
        return Array(keyedJobs.values)
    }
    
    private var jobsDefaultsKey: String {
        return "com.esri.arcgis.runtime.toolkit.jobManager.\(jobManagerID).jobs"
    }
    
    /// Create a JobManager with an ID.
    public required init(jobManagerID: String) {
        self.jobManagerID = jobManagerID
        super.init()
        loadJobsFromUserDefaults()
    }
    
    deinit {
        keyedJobs = [:]
    }
    
    private func toJSON() -> JSONDictionary {
        return keyedJobs.compactMapValues { try? $0.toJSON() }
    }
    
    // observing job status code
    
    private func observeJobStatus(job: AGSJob) {
        job.addObserver(self, forKeyPath: #keyPath(AGSJob.status), context: &kvoContext)
    }
    
    private func unObserveJobStatus(job: AGSJob) {
        job.removeObserver(self, forKeyPath: #keyPath(AGSJob.status))
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            if keyPath == #keyPath(AGSJob.status) {
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
    @discardableResult public func register(job: AGSJob) -> String {
        let jobUniqueID = NSUUID().uuidString
        keyedJobs[jobUniqueID] = job
        return jobUniqueID
    }

    /**
     Unregister a Job with the JobManager
     Returns true if it found the Job and was able to unregister it.
     */
    @discardableResult public func unregister(job: AGSJob) -> Bool {
        if let jobUniqueID = keyedJobs.first(where: { $0.value === job })?.key {
            keyedJobs[jobUniqueID] = nil
            return true
        }
        return false
    }
    
    /**
     Unregister a Job with the JobManager, using the Job's unique ID.
     Returns true if it found the Job and was able to unregister it.
     */
    @discardableResult public func unregister(jobUniqueID: String) -> Bool {
        let removed = keyedJobs.removeValue(forKey: jobUniqueID) != nil
        return removed
    }
    
    /// Clears the finished Jobs from the Job manager.
    public func clearFinishedJobs() {
        keyedJobs = keyedJobs.filter {
            let status = $0.value.status
            return !(status == .failed || status == .succeeded)
        }
    }
    
    /**
     Checks the status for all Jobs and returns when completed.
     */
    @discardableResult public func checkStatusForAllJobs(completion: @escaping (Bool)->Void) -> AGSCancelable {
        let cancelGroup = CancelGroup()
        
        let group = DispatchGroup()
        
        var completedWithoutErrors = true
        
        keyedJobs.forEach {
            group.enter()
            let cancellable = $0.value.checkStatus { error in
                if error != nil {
                    completedWithoutErrors = false
                }
                group.leave()
            }
            cancelGroup.children.append(cancellable)
        }
        
        group.notify(queue: .main) {
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
        if keyedJobs.isEmpty {
            return completionHandler(.noData)
        } else {
            checkStatusForAllJobs { completedWithoutErrors in
                if completedWithoutErrors {
                    completionHandler(.newData)
                }
                else{
                    completionHandler(.failed)
                }
            }
        }
    }

    
    /// Resume all paused and not-started jobs.
    public func resumeAllPausedJobs(statusHandler: @escaping JobStatusHandler, completion: @escaping JobCompletionHandler) {
        // Note that a job is also paused if it is created from JSON. So any jobs that have been stored in
        // UserDefaults and reloaded will be in the paused state.
        keyedJobs.lazy.filter({ $0.value.status == .paused || $0.value.status == .notStarted }).forEach {
            $0.value.start(statusHandler: statusHandler, completion:completion)
        }
    }
    
    /**
     Saves all Jobs to User Defaults.
     This happens automatically when the jobs are registered/unregistered.
     It also happens when job status changes.
     */
    private func saveJobsToUserDefaults() {
        guard !suppressSaveToUserDefaults else { return }
        
        UserDefaults.standard.set(self.toJSON(), forKey: jobsDefaultsKey)
    }
    
    private func loadJobsFromUserDefaults() {
        if let storedJobsJSON = UserDefaults.standard.dictionary(forKey: jobsDefaultsKey) {
            suppressSaveToUserDefaults = true
            keyedJobs = storedJobsJSON.compactMapValues { $0 is JSONDictionary ? (try? AGSJob.fromJSON($0)) as? AGSJob : nil }
            suppressSaveToUserDefaults = false
        }
    }
}

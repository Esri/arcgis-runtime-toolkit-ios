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
    
    /// The JobManager ID, provided during initialization.
    public let jobManagerID: String
    
    /// Flag to signify that we shouldn't write to User Defaults.
    ///
    /// Used internally when reading stored `AGSJob`s from the User Defaults during init().
    private var suppressSaveToUserDefaults = false
    
    private var kvoContext = 0
    
    /// A dictionary of Unique IDs and `AGSJob`s that the `JobManager` is managing.
    public private(set) var keyedJobs = [String: AGSJob]() {
        willSet {
            // Need `self` because of a Swift bug.
            self.keyedJobs.values.forEach { unObserveJobStatus(job: $0) }
        }
        didSet {
            keyedJobs.values.forEach { observeJobStatus(job: $0) }
            
            // If there was a change, then re-store the serialized AGSJobs in UserDefaults
            if keyedJobs != oldValue {
                saveJobsToUserDefaults()
            }
        }
    }
    
    /// A convenience accessor to the `AGSJob`s that the `JobManager` is managing.
    public var jobs: [AGSJob] {
        return Array(keyedJobs.values)
    }
    
    private var jobsDefaultsKey: String {
        return "com.esri.arcgis.runtime.toolkit.jobManager.\(jobManagerID).jobs"
    }
    
    private var jobStatusObservations = [String: NSKeyValueObservation]()
    
    /// Create a JobManager with an ID.
    ///
    /// - Parameter jobManagerID: An arbitrary identifier for this JobManager.
    public required init(jobManagerID: String) {
        self.jobManagerID = jobManagerID
        super.init()
        loadJobsFromUserDefaults()
    }
    
    deinit {
        keyedJobs.values.forEach { unObserveJobStatus(job: $0) }
    }
    
    private func toJSON() -> JSONDictionary {
        return keyedJobs.compactMapValues { try? $0.toJSON() }
    }
    
    // Observing job status code
    private func observeJobStatus(job: AGSJob) {
        let observer = job.observe(\.status, options: [.new]) { [weak self] (_, _) in
            self?.saveJobsToUserDefaults()
        }
        jobStatusObservations[job.serverJobID] = observer
    }
    
    private func unObserveJobStatus(job: AGSJob) {
        if let observer = jobStatusObservations[job.serverJobID] {
            observer.invalidate()
            jobStatusObservations.removeValue(forKey: job.serverJobID)
        }
    }
    
    /// Register an `AGSJob` with the `JobManager`.
    ///
    /// - Parameter job: The AGSJob to register.
    /// - Returns: A unique ID for the AGSJob's registration which can be used to unregister the job.
    @discardableResult
    public func register(job: AGSJob) -> String {
        let jobUniqueID = NSUUID().uuidString
        keyedJobs[jobUniqueID] = job
        return jobUniqueID
    }
    
    /// Unregister an `AGSJob` from the `JobManager`.
    ///
    /// - Parameter job: The job to unregister.
    /// - Returns: `true` if the job was found, `false` otherwise.
    @discardableResult
    public func unregister(job: AGSJob) -> Bool {
        if let jobUniqueID = keyedJobs.first(where: { $0.value === job })?.key {
            keyedJobs[jobUniqueID] = nil
            return true
        }
        return false
    }
    
    /// Unregister an `AGSJob` from the `JobManager`.
    ///
    /// - Parameter jobUniqueID: The job's unique ID, returned from calling `register()`.
    /// - Returns: `true` if the Job was found, `false` otherwise.
    @discardableResult
    public func unregister(jobUniqueID: String) -> Bool {
        let removed = keyedJobs.removeValue(forKey: jobUniqueID) != nil
        return removed
    }
    
    /// Clears the finished `AGSJob`s from the `JobManager`.
    public func clearFinishedJobs() {
        keyedJobs = keyedJobs.filter {
            let status = $0.value.status
            return !(status == .failed || status == .succeeded)
        }
    }
    
    /// Checks the status for all `AGSJob`s calling a completion block when completed.
    ///
    /// - Parameter completion: A completion block that is called when the status of all `AGSJob`s has been checked. Passed `true` if all statuses were retrieves successfully, or `false` otherwise.
    /// - Returns: An `AGSCancelable` group that can be used to cancel the status checks.
    @discardableResult
    public func checkStatusForAllJobs(completion: @escaping (Bool) -> Void) -> AGSCancelable {
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
    
    /// A helper function to call from a UIApplication's delegate when using iOS's Background Fetch capabilities.
    ///
    /// Checks the status for all `AGSJob`s and calls the completion handler when done.
    ///
    /// This method can be called from:
    /// `func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void))`
    ///
    /// See [Apple's documentation](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application)
    /// for more details.
    ///
    /// - Parameters:
    ///   - application:  See [Apple's documentation](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application)
    ///   - completionHandler:  See [Apple's documentation](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application)
    @available(iOS, deprecated: 13.0, message: "Please use 'UIApplication.shared.beginBackgroundTask(expirationHandler:)' when kicking off your job instead")
    public func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if keyedJobs.isEmpty {
            return completionHandler(.noData)
        } else {
            checkStatusForAllJobs { completedWithoutErrors in
                if completedWithoutErrors {
                    completionHandler(.newData)
                } else {
                    completionHandler(.failed)
                }
            }
        }
    }
    
    /// Resume all paused and not-started `AGSJob`s.
    ///
    /// An `AGSJob`'s status is `.paused` when it is created from JSON. So any `AGSJob`s that have been reloaded from User Defaults will be in the `.paused` state.
    ///
    /// See the [Tasks and Jobs](https://developers.arcgis.com/ios/programming-patterns/tasks-and-jobs/#pause-resume-or-cancel-a-job)
    /// guide topic for more details.
    ///
    /// - Parameters:
    ///   - statusHandler: A callback block that is called by each active `AGSJob` when the `AGSJob`'s status changes or its messages array is updated.
    ///   - completion: A callback block that is called by each `AGSJob` when it has completed.
    public func resumeAllPausedJobs(statusHandler: @escaping JobStatusHandler, completion: @escaping JobCompletionHandler) {
        keyedJobs.lazy.filter { $0.value.status == .paused || $0.value.status == .notStarted }.forEach {
            $0.value.start(statusHandler: statusHandler, completion: completion)
        }
    }
    
    /// Pauses any currently running job.
    public func pauseAllJobs() {
        keyedJobs.values.forEach {
            guard $0.status == .started else { return }
            $0.progress.pause()
        }
    }
    
    /// Saves all managed `AGSJob`s to User Defaults.
    ///
    /// This happens automatically when the `AGSJob`s are registered/unregistered.
    /// It also happens when an `AGSJob`'s status changes.
    private func saveJobsToUserDefaults() {
        guard !suppressSaveToUserDefaults else { return }
        
        UserDefaults.standard.set(self.toJSON(), forKey: jobsDefaultsKey)
    }
    
    /// Load any `AGSJob`s that have been saved to User Defaults.
    ///
    /// This happens when the `JobManager` is initialized. All `AGSJob`s will be in the `.paused` state when first restored from JSON.
    ///
    /// See the [Tasks and Jobs](https://developers.arcgis.com/ios/programming-patterns/tasks-and-jobs/#pause-resume-or-cancel-a-job)
    /// guide topic for more details.
    private func loadJobsFromUserDefaults() {
        if let storedJobsJSON = UserDefaults.standard.dictionary(forKey: jobsDefaultsKey) {
            suppressSaveToUserDefaults = true
            keyedJobs = storedJobsJSON.compactMapValues { $0 is JSONDictionary ? (try? AGSJob.fromJSON($0)) as? AGSJob : nil }
            suppressSaveToUserDefaults = false
        }
    }
}

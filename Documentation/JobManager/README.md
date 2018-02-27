# Job Manager

Jobs by definition are long running operations and especially when using mobile devices, applications are backgrounded, terminated and re-launched based on rules specific to each platform. Our jobs supports pause and resume workflows but we don't have an easy way to implement persistence to the application lifecycles without quite a bit custom code.

The Job Manager is a toolkit component that you can just plug into the application and then give it tasks you want to persist when the application is backgrounded/terminated and an easy way to rehydrate when the application is re-launched.

### Usage

```swift

	// create and load a task
        let task = AGSGeodatabaseSyncTask(url: URL)
	task.load{ error in

            // make sure we are still around...
            guard let strongSelf = self else {
                return
            }

	    // make sure task does not get released
            guard let strongTask = task else{
                return
            }

	    // set up params
            let params = AGSGenerateGeodatabaseParameters()
	    // <param setup here>

	    // generate job
            let job = strongTask.generateJob(with: params, downloadFileURL: downloadURL)

            // register the job with our JobManager shared instance
            JobManager.shared.register(job: job)
            
            // start the job
            job.start(statusHandler: strongSelf.jobStatusHandler, completion: strongSelf.jobCompletionHandler)

	}		
```

To see it in action, try out the [Examples](../../Examples) and refer to [JobManagerExample.swift](../../Examples/ArcGISToolkitExamples/JobManagerExample.swift) in the project.





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

import Foundation

internal class Coalescer {
    // Class to coalesce actions into intervals.
    // This is helpful for the Scalebar because we get updates to the visibleArea up to 60hz and we
    // don't need to redraw the Scalebar that often
    
    var dispatchQueue: DispatchQueue
    var interval: DispatchTimeInterval
    var action: (() -> Void)
    
    init (dispatchQueue: DispatchQueue, interval: DispatchTimeInterval, action: @escaping (() -> Void)) {
        self.dispatchQueue = dispatchQueue
        self.interval = interval
        self.action = action
    }
    
    private var count = 0
    
    func ping() {
        // synchronize to a serial queue, in this case main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.ping() }
            return
        }
        
        // increment the count
        count += 1
        
        // the first time the count is incremented, it dispatches the action
        if count == 1 {
            dispatchQueue.asyncAfter(deadline: DispatchTime.now() + interval) {
                // call the action
                self.action()
                
                // reset the count
                self.resetCount()
            }
        }
    }
    
    private func resetCount() {
        // synchronize to a serial queue, in this case main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.count = 0 }
        } else {
            self.count = 0
        }
    }
}

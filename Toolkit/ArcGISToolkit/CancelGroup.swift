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

/**
 Wraps multiple AGSCancelables into a single cancelable object.
 */
@objc
public class CancelGroup: NSObject, AGSCancelable {
    /// Cancels all the AGSCancelables in the group.
    public func cancel() {
        children.forEach { $0.cancel() }
        _canceled = true
    }
    
    private var _canceled: Bool = false
    
    /// Whether or not the group is canceled.
    public func isCanceled() -> Bool {
        return _canceled
    }
    
    /// The children associated with this group.
    public var children: [AGSCancelable] = [AGSCancelable]()
}

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
import ArcGISToolkit

class ExamplesViewController: VCListViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Toolkit Samples"
        
        self.viewControllerInfos = [
            ("Compass", CompassExample.self, nil),
            ("Measure", MeasureExample.self, nil),
            ("Scalebar", ScalebarExample.self, nil),
            ("Legend", LegendExample.self, nil),
            ("Job Manager", JobManagerExample.self, nil),
            ("Time Slider", TimeSliderExample.self, nil),
            ("Popup Controller", PopupExample.self, nil),
            ("Template Picker", TemplatePickerExample.self, nil),
            ("AR", ARExample.self, nil),
            ("Bookmarks", BookmarksExample.self, nil)
        ]
    }
}

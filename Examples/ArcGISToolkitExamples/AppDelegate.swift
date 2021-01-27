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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Override point for customization after application launch.

        #warning("Require user to sign in with an ArcGIS identity or set your developer API key")
        /*
         Use of Esri location services, including basemaps and geocoding, requires either an ArcGIS identity or an API Key. For more information see https://links.esri.com/arcgis-runtime-security-auth.
         1) ArcGIS identity: An ArcGIS named user account that is a member of an organization in ArcGIS Online or ArcGIS Enterprise.
         2) API key: A permanent key that gives your application access to Esri location services. Create a new API key or access existing API keys from your ArcGIS for Developers dashboard (https://links.esri.com/arcgis-api-keys).
         Production deployment of applications built with ArcGIS Runtime requires you to license ArcGIS Runtime functionality. For more information see https://links.esri.com/arcgis-runtime-license-and-deploy.
         */
        // Uncomment the following line to access Esri location services using an API key.
        // AGSArcGISRuntimeEnvironment.apiKey = "<#API Key#>"
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    /// We need to forward these calls to ArcGIS so that we can be a good citizen and allow ArcGIS to call the completionHandler
    /// once the associated download session is finished handling events.
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        AGSApplicationDelegate.shared().application(
            application,
            handleEventsForBackgroundURLSession: identifier,
            completionHandler: completionHandler
        )
    }
}

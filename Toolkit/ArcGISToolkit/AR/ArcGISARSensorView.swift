//
// Copyright 2019 Esri.

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
import AVFoundation
import CoreMotion
import ArcGIS

public enum LocationType {
    case anglesOnly
    case positionOnly
    case anglesAndPosition
}

public class ArcGISARSensorView: UIView {

    public var locationType: LocationType = .anglesAndPosition {
        didSet {
            // need to update location and heading updates to account for new LocationType
        }
    }
    
    public var sceneView = AGSSceneView(frame: .zero) {
        willSet(newSceneview) {
            removeSubviewAndConstraints(sceneView)
        }
        didSet {
            addSubviewWithConstraints(sceneView)
            
            // make our sceneView's background transparent
            sceneView.isBackgroundTransparent = true
            sceneView.atmosphereEffect = .none
        }
    }

    public var useAbsoluteHeading: Bool = true
    
    // MARK: private properties

    public var renderVideoFeed = true
    
    // has the client been notfiied of start/failure
    private var notifiedStartOrFailure = false

    private lazy var locationManager: CLLocationManager = {
        let lm = CLLocationManager()
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.delegate = self
        return lm
    }()

    private lazy var motionManager: CMMotionManager = {
        let mm = CMMotionManager()
        mm.deviceMotionUpdateInterval = 1.0 / 60.0
        mm.showsDeviceMovementDisplay = true
        return mm
    }()

    // MARK: Capture session
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private lazy var session = AVCaptureSession()
    
    // Communicate with the capture session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    private var setupResult: SessionSetupResult = .success
    var videoDeviceInput: AVCaptureDeviceInput!
    private lazy var cameraView = CameraView(frame:CGRect.zero)
    
    private var orientationQuat: simd_quatf = simd_quaternion(Float(0), Float(0), Float(0), Float(1))

    // MARK: intializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInitialization()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInitialization()
    }
    
    required public convenience init(renderVideoFeed: Bool){
        self.init(frame: CGRect.zero)
        self.renderVideoFeed = renderVideoFeed
    }
    
    private func sharedInitialization(){
        
        //
        // make our sceneView's background transparent
        sceneView.isBackgroundTransparent = true
        sceneView.atmosphereEffect = .none

        // add sceneView to our view
        addSubviewWithConstraints(sceneView)
        
        if renderVideoFeed {
            // Set up the video preview view.
            addSubviewWithConstraints(cameraView, index: 0)
            cameraView.session = session
            
            prepVideoFeed()
        }
    }

    public func startTracking() {
        notifiedStartOrFailure = false
        
        // determine status of location manager
        let authStatus = CLLocationManager.authorizationStatus()
        switch authStatus {
        case .notDetermined:
            startWithAccessNotDetermined()
        case .restricted, .denied:
            startWithAccessDenied()
        case .authorizedAlways, .authorizedWhenInUse:
            startWithAccessAuthorized()
        }
        
        // start motion manager
        startUpdatingLocationAndHeading()
        
        if renderVideoFeed {
            setupSession()
        }
    }
    
    public func stopTracking() {
        locationManager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.stopUpdatingHeading()
        }
        
        motionManager.stopDeviceMotionUpdates()

        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.setupResult == .success {
                strongSelf.session.stopRunning()
                
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                NotificationCenter.default.removeObserver(strongSelf)
            }
        }
    }
    
    // Called when device orientation changes
    @objc func orientationChanged(notification: Notification) {
        // handle rotation here
        updateCameraViewOrientation()
    }

    private func addSubviewWithConstraints(_ subview: UIView, index: Int = -1) {
        // add subView to view and setup constraints
        if index >= 0 {
            insertSubview(subview, at: index)
        }
        else {
            addSubview(subview)
        }
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            subview.topAnchor.constraint(equalTo: self.topAnchor),
            subview.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
    }
    
    private func removeSubviewAndConstraints(_ subview: UIView) {
        // remove subView from view along with constraints
        subview.removeFromSuperview()
        removeConstraints(subview.constraints)
    }
    
    private func startWithAccessNotDetermined() {
        if (Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil) {
            locationManager.requestWhenInUseAuthorization()
        }
        if (Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil) {
            locationManager.requestAlwaysAuthorization()
        }
        else{
            didStartOrFailWithError(ArcGISARView.missingPListKeyError())
        }
    }
    
    private func startUpdatingLocationAndHeading() {
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        startUpdatingAngles()
    }
    
    private func startWithAccessDenied() {
        didStartOrFailWithError(ArcGISARView.accessDeniedError())
    }
    
    private func startWithAccessAuthorized() {
        startUpdatingLocationAndHeading()
    }
    
    private func didStartOrFailWithError(_ error: Error?) {
        // TODO: present error to user...
        
        notifiedStartOrFailure = true;
    }
    
    private func handleAuthStatusChangedAccessDenied() {
        // auth status changed to denied
        if !notifiedStartOrFailure {
            stopTracking()
            // we were waiting for user prompt to come back, so notify
            didStartOrFailWithError(ArcGISARView.accessDeniedError())
        }
    }
    
    private func handleAuthStatusChangedAccessAuthorized() {
        // auth status changed to authorized
        if !notifiedStartOrFailure {
            // we were waiting for status to come in to start the datasource
            // now that we have authorization - start it
            didStartOrFailWithError(nil)
            
            // need to start location manager updates
            startUpdatingLocationAndHeading()
        }
    }
    
    private func finalizeStart() {
        // TODO:  is there anything to do here?
    }
    
    private func startUpdatingAngles() {
        let motionQueue = OperationQueue.init()
        motionQueue.qualityOfService = .userInteractive
        motionQueue.maxConcurrentOperationCount = 1
        
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] (motion, error) in
            guard let quat = self?.motionManager.deviceMotion?.attitude.quaternion,
                let orientationQuat = self?.orientationQuat else { return }
            let currentQuat = simd_quaternion(Float(quat.x), Float(quat.y), Float(quat.z), Float(quat.w))
            let finalQuat = simd_mul(currentQuat, orientationQuat)
            
//            print("updating device motion: \(finalQuat)")
            //use `finalQuat` to update position/orientation of camera
        }
    }
    
    // MARK: Video
    
    func updateCameraViewOrientation() {
        if let videoPreviewLayerConnection = cameraView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }
            
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }

    private func prepVideoFeed() {
        //
        // Check video authorization status. Video access is required and audio
        // access is optional. If audio access is denied, audio is not recorded
        // during movie recording.
        //
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            setupResult = .success
            break
            
        case .notDetermined:
            // The user has not yet been presented with the option to grant
            // video access. We suspend the session queue to delay session
            // setup until the access request has completed.
            //
            // Note that audio access will be implicitly requested when we
            // create an AVCaptureDeviceInput for audio during session setup.
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { [weak self] (accessGranted) in
                if !accessGranted {
                    self?.setupResult = .notAuthorized
                }
                else {
                    self?.setupResult = .success
                    self?.sessionQueue.resume()
                }
            }
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        // Setup the capture session.
        // In general it is not safe to mutate an AVCaptureSession or any of its
        // inputs, outputs, or connections from multiple threads at the same time.
        //
        // Why not do all of this on the main queue?
        // Because AVCaptureSession.startRunning() is a blocking call which can
        // take a long time. We dispatch session setup to the sessionQueue so
        // that the main queue isn't blocked, which keeps the UI responsive.
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func setupSession() {

        // session setup
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.session.startRunning()
                DispatchQueue.main.async {
                    
                    self.updateCameraViewOrientation()
                    
                    // add observer to catch orientation changes
                    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(self.orientationChanged(notification:)),
                        name: UIDevice.orientationDidChangeNotification,
                        object: nil
                    )
                }
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("ArcGISARSensorView does not have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "ArcGISARSensorView", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    
                    guard let rootController = UIApplication.shared.keyWindow?.rootViewController else { return }
                    rootController.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                    let alertController = UIAlertController(title: "ArcGISARSensorView", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    
                    guard let rootController = UIApplication.shared.keyWindow?.rootViewController else { return }
                    rootController.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    // MARK: Session Management
    
    // Call this on the session queue.
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            //            if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
            //                defaultVideoDevice = dualCameraDevice
            //            }
            //            else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
            //                // If the back dual camera is not available, default to the back wide angle camera.
            //                defaultVideoDevice = backCameraDevice
            //            }
            //            else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
            // In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
            defaultVideoDevice = AVCaptureDevice.default(for: .video)
            //            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
//
//                DispatchQueue.main.async { [weak self] in
//                    self?.cameraView.videoPreviewLayer.connection!.videoOrientation = .landscapeLeft
//                }
            }
            else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }

    // MARK: Errors
    class func notSupportedError() -> NSError {
        let userInfo = [NSLocalizedDescriptionKey : "The device does not support ARKit functionality."]
        return NSError(domain: AGSErrorDomain, code: 0, userInfo: userInfo)
    }
    
    class func accessDeniedError() -> NSError{
        let userInfo = [NSLocalizedDescriptionKey : "Access to the device location is denied."]
        return NSError(domain: kCLErrorDomain, code: CLError.Code.denied.rawValue, userInfo: userInfo)
    }
    
    class func missingPListKeyError() -> NSError{
        let userInfo = [NSLocalizedDescriptionKey : "You must specify a location usage description key (NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription) in your plist."]
        return NSError(domain: kCLErrorDomain, code: CLError.Code.denied.rawValue, userInfo: userInfo)
    }

}

// MARK: - CLLocationManagerDelegate

extension ArcGISARSensorView: CLLocationManagerDelegate {
    /*
     *  locationManager:didUpdateLocations:
     *
     *  Discussion:
     *    Invoked when new locations are available.  Required for delivery of
     *    deferred locations.  If implemented, updates will
     *    not be delivered to locationManager:didUpdateToLocation:fromLocation:
     *
     *    locations is an array of CLLocation objects in chronological order.
     */
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0.0 else { return }
        
        let locationPoint = AGSPoint(x: location.coordinate.longitude,
                                     y: location.coordinate.latitude,
                                     z: location.altitude,
                                     spatialReference: .wgs84())
//        let camera = AGSCamera(location: locationPoint, heading: 0.0, pitch: 0.0, roll: 0.0)
//        sceneView.setViewpointCamera(camera)
        
//        finalizeStart()  // is this needed?
        
//        print("updating location: \(locationPoint)")
    }
    
    /*
     *  locationManager:didFailWithError:
     *
     *  Discussion:
     *    Invoked when an error has occurred. Error types are defined in "CLError.h".
     */
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        didStartOrFailWithError(error)
    }
    
    /*
     *  locationManager:didChangeAuthorizationStatus:
     *
     *  Discussion:
     *    Invoked when the authorization status changes for this application.
     */
    public  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let authStatus = CLLocationManager.authorizationStatus()
        switch authStatus {
        case .notDetermined:
            break
        case .restricted, .denied:
            self.handleAuthStatusChangedAccessDenied()
        case .authorizedAlways, .authorizedWhenInUse:
            self.handleAuthStatusChangedAccessAuthorized()
        }
    }
    
    /*
     *  Discussion:
     *    Invoked when location updates are automatically paused.
     */
    public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        
    }
    
    /*
     *  Discussion:
     *    Invoked when location updates are automatically resumed.
     *
     *    In the event that your application is terminated while suspended, you will
     *      not receive this notification.
     */
    @available(iOS 6.0, *)
    public func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        
    }
}

// MARK: CameraView

/// CameraView - view which displays the live camera image
class CameraView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    // MARK: UIView
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

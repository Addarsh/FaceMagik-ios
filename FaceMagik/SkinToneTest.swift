//
//  SkinToneTest.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/20/22.
//

import UIKit
import AVFoundation

class SkinToneTest: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    static func storyboardInstance() -> UINavigationController? {
        let className = String(describing: SkinToneTest.self)
        let storyboard = UIStoryboard(name: className, bundle: nil)
        return storyboard.instantiateInitialViewController() as UINavigationController?
    }

}

class SkinToneDetectionSession: UIViewController {
    
    enum SessionState {
        case NOT_STARTED
        case RUNNING
        case COMPLETE
        case USER_SESSION_CREATED
        case ROTATION_STARTED
        case ROTATION_COMPLETE
        case NAVIGATION_STARTED
    }
    
    // Class level constant to control which flow is triggered.
    enum CurrentFlow {
        case NAVIGATION_PER_UPLOAD
        case ROTATION_AND_WALKING
    }
    private let currentFlow = CurrentFlow.ROTATION_AND_WALKING
    
    // Outlets to Storyboard.
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var totalHeadingsLabel: UILabel!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var imagesSentLabel: UILabel!
    @IBOutlet weak var imagesReceivedLabel: UILabel!
    @IBOutlet weak var testLabel: UILabel!
    var progressView: UIProgressView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet private var previewView: PreviewView!
    
    // Camera variables.
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let notifCenter = NotificationCenter.default
    private let captureSessionQueue = DispatchQueue(label: "user video queue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    private let videoOutputQueue = DispatchQueue(label: "output video frames queue")
    var pictureClickStartTime: Date = Date()
    
    // Skin tone session variables.
    private let backendServiceQueue = DispatchQueue(label: "backend service queue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    var sessionState = SessionState.NOT_STARTED
    var backendService: BackendService?
    var faceContourDetector: FaceContourDetector?
    var sessionId = ""
    var lastInstruction = ""
    var lastImage: CIImage?
    let PROCESSING_ALERT = "Processing..."
    let INTIALIZING_ALERT = "Initializing..."
    let PROCESSING_IMAGES_PLEASE_WAIT = "Processing images..."
    
    // User Session Service variables.
    var userSessionService: UserSessionService?
    var userSessionId = ""
    var rotationManager: RotationManager?
    var allHeadings: Set<Int> = []
    var headingsUploadedToServer: Set<Int> = []
    var numRotationImagesSent = 0
    var numRotationImagesReceived = 0
    var lastHeadingValue: Int = -1
    private let rotationManagerQueue = DispatchQueue(label: "rotation manager queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        notifCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        backendService = BackendService(sessionResponseHandler: self)
        userSessionService = UserSessionService(userSessionServiceDelegate: self, is_remote_endpoint: false)
        rotationManager = RotationManager()
        faceContourDetector = FaceContourDetector(faceContourDelegate: self)

        if !isCameraUseAuthorized() {
            return
        }
        
        if !setUpVideoCaptureSession() {
            return
        }
        
        captureSessionQueue.async {
             self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.setupLivePreview()
            }
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        backendServiceQueue.async {
            if (self.currentFlow == CurrentFlow.NAVIGATION_PER_UPLOAD) {
                guard let backendService = self.backendService else {
                    print ("Backend service not found")
                    return
                }
                backendService.createSkinToneSession()
            }
        }
        
        // Provide instruction to user.
        let alert = Utils.createInstuctionAlert(message: "Start rotating slowly in the clockwise direction(-->) as we assess lighting conditions.", completionHandler: { _ in
            // Start user session.
            self.backendServiceQueue.async {
                if (self.currentFlow == CurrentFlow.ROTATION_AND_WALKING) {
                    guard let userSessionService = self.userSessionService else {
                        print ("UserSession service not found")
                        return
                    }
                    userSessionService.createUserSession()
                }
            }
        })
        self.present(alert, animated: true)
    }
    
    func setupLivePreview() {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(videoPreviewLayer)
        
    }
    
    private func  isCameraUseAuthorized() -> Bool {
        var authorized = false
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            // Request user permission to use camera.
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                authorized = granted
            })
            break
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            authorized = true
            break
        @unknown default:
            break
        }
        return authorized
    }
    
    private func setUpVideoCaptureSession() -> Bool {
        captureSession.beginConfiguration()
        
        defer {captureSession.commitConfiguration()}
        
        // Configure camera device.
        guard let cameraDevice = AVCaptureDevice.default(.builtInTrueDepthCamera,
                                                        for: .video, position: .front) else {
            print ("Could not initialize camera device")
            return false
        }
        
        // Configure camera input.
        guard let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice), captureSession.canAddInput(cameraInput) else {
            print ("Could not initialize camera input")
            return false
        }
        captureSession.addInput(cameraInput)
        
        // Configure camera output.
        guard captureSession.canAddOutput(videoOutput) else {
            print ("Could not initialize camera output")
            return false
        }
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        captureSession.addOutput(videoOutput)
        
        return true
    }
    
    // Handler for trigerring flow that allows user to capture and send pictures to the server for processing. The result from the
    // server is a navigation instruction for the direction the user must rotate to face the primary direction of light in the scene.
    // To test another flow in the same class, this handler's fucntionality will be controlled by a class level variable. When disabled,
    // this handler will return a no-op, otherwise the flow mentioned above will execute.
    @IBAction func didClickPicture(_ sender: UIButton) {
        if(currentFlow == CurrentFlow.ROTATION_AND_WALKING) {
            return
        }
        animateButton()
        backendServiceQueue.async {
            guard let faceContourDetector = self.faceContourDetector else {
                print ("Face Mask detector not found")
                return
            }


            switch(self.sessionState) {
            case SessionState.NOT_STARTED:
                print ("Error session not started")
                break
            case SessionState.RUNNING:
                guard let ciImage = self.lastImage else {
                    print ("Last image not found")
                    return
                }
                let resizedWidth = CGFloat(600)
                guard let uiImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: UIImage.Orientation.right).resized(toWidth: resizedWidth) else {
                    print ("UIImage resize failed")
                    return
                }
                self.pictureClickStartTime = Date()
                faceContourDetector.detect(uiImage: uiImage)
            case SessionState.COMPLETE:
                print ("Session complete")
            default:
                print ("Session state: \(self.sessionState) is not supported in Backend Service")
            }
        }
    }
    
    
    @objc private func appMovedToBackground() {
        notifCenter.removeObserver(self)
        // Pop view.
        self.navigationController?.popViewController(animated: true)
    }
    
    // When the view disappears.
    override func viewDidDisappear(_ animated: Bool) {
        captureSessionQueue.async {
            self.captureSession.stopRunning()
        }
        rotationManagerQueue.async {
            self.rotationManager?.stopRotationUpdates()
        }
    }
    
    private func animateButton() {
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.2, initialSpringVelocity: 0.5, options: .curveEaseIn,
            animations: {
                self.cameraButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            },
            completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.2, initialSpringVelocity: 0.5, options: .curveEaseIn, animations:  {
                    self.cameraButton.transform = CGAffineTransform.identity
            }, completion: nil)
        })
    }
    
    // Must be called in Main thread.
    private func updateProgress(ratio: Float) {
        self.progressView.progress = ratio
    }
    
}

// Responses from backend UserSessionService.
extension SkinToneDetectionSession: UserSessionServiceDelegate {
    
    // Session creation response handler.
    func onSessionCreation(userSessionId: String) {
        backendServiceQueue.async {
            self.userSessionId = userSessionId
            self.sessionState = SessionState.USER_SESSION_CREATED
        }
        
        DispatchQueue.main.async {
            self.instructionLabel.startBlink()
        }
        
        self.rotationManagerQueue.async {
            self.rotationManager?.startRotationUpdates(rotationManagerDelegate: self)
        }
    }
    
    // Rotation image upload response received handler.
    func uploadRotationImageResponseReceived() {
        backendServiceQueue.async {
            self.numRotationImagesReceived += 1
            DispatchQueue.main.async {
                self.imagesReceivedLabel.text = String(self.numRotationImagesReceived)
            }
            
            // Even though we should be comparing images sent and images received to be equal, in local testing
            // we found that the last image sometimes takes a really long time to be received (no idea why).
            // By checking for 1 less image received, we work around this problem without needing timeouts. The
            // assumption here is that enough pictures have been collected till then that missing out on the final one
            // will not affect the result.
            if (self.sessionState == SessionState.ROTATION_COMPLETE) {
                if (self.numRotationImagesSent - 1 == self.numRotationImagesReceived) {
                    // Request server to fetch Rotation result.
                    self.userSessionService?.getRotationResult(userSessionId: self.userSessionId)
                    
                    DispatchQueue.main.async {
                        self.updateProgress(ratio: 1.0)
                        
                        // Dismiss waiting alert.
                        self.dismiss(animated: false, completion: nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.updateProgress(ratio: Float(self.numRotationImagesReceived)/Float(self.numRotationImagesSent))
                    }
                }
            }
        }
    }
    
    // Rotation result response handler.
    func primaryHeadingDirection(heading: Int) {
        // Sleep for 0.5 seconds. This is to give enough time for previous alert to be dismissed without dismissing the whole app instead.
        Thread.sleep(forTimeInterval: 0.5)
        
        DispatchQueue.main.async {
            // Provide instruction to user.
            let alert = Utils.createInstuctionAlert(message: "Follow instructions to face the direction of light. Keep rotating until instructed to stop.", completionHandler: { _ in
                // Start navigation session.
                self.rotationManagerQueue.async {
                    self.rotationManager?.navigateUserToHeading(navigateUserDelegate: self, targetHeading: heading)
                }
                self.backendServiceQueue.async {
                    self.sessionState = SessionState.NAVIGATION_STARTED
                    DispatchQueue.main.async {
                        self.instructionLabel.startBlink()
                    }
                }
            })
            
            self.present(alert, animated: true)
        }
    }
}

// Updates from rotation manager in rotation mode.
extension SkinToneDetectionSession: RotationManagerDelegate {
    
    func updatedHeading(heading: Int) {
        backendServiceQueue.async {
            if (self.sessionState != SessionState.ROTATION_STARTED) {
                self.sessionState = SessionState.ROTATION_STARTED
                DispatchQueue.main.async {
                    self.instructionLabel.text = "Rotate slowly towards your Right -->"
                }
            }
            self.allHeadings.insert(heading)
            DispatchQueue.main.async {
                self.totalHeadingsLabel.text = "total headings: " + String(self.allHeadings.count)
            }
            
            if (self.headingsUploadedToServer.contains(heading)) {
                // Image uploaded given heading already.
                return
            }
            if (self.lastHeadingValue != -1) {
                if (abs(RotationManager.smallestDegreeDiff(self.lastHeadingValue, heading)) < 10) {
                    // Skip face detection for this heading.
                    return
                } else {
                    DispatchQueue.main.async {
                        self.instructionLabel.text = "Keep rotating..."
                    }
                }
            }
            
            self.detectFace(heading: heading)
            
            // Update heading values found.
            self.headingsUploadedToServer.insert(heading)
            self.lastHeadingValue = heading
        }
        
        // Update UI with heading value.
        DispatchQueue.main.async {
            self.headingLabel.text = "heading: " + String(heading)
        }
    }
    
    // Handler to respond to rotation completion event.
    func oneRotationComplete() {
        
        DispatchQueue.main.async {
            
            self.backendServiceQueue.async {
                self.sessionState = SessionState.ROTATION_COMPLETE
            }
            
            // Clear instruction text.
            DispatchQueue.main.async {
                self.instructionLabel.text = ""
                self.instructionLabel.stopBlink()
            }
            
            // Create alert asking user to wait.
            let alert = Utils.createProcessingAlert(message: self.PROCESSING_IMAGES_PLEASE_WAIT)
            self.present(alert, animated: true, completion: {
                //  Add your progressbar after alert is shown (and measured).
                let margin:CGFloat = 8.0
                let rect = CGRect(x: margin, y: 50, width: alert.view.frame.width - margin * 2.0 , height: 2.0)
                self.progressView = UIProgressView(frame: rect)
                self.progressView!.progress = 0.0
                self.progressView!.tintColor = .green
                alert.view.addSubview(self.progressView!)
            })
        }
    }
    
    
    private func detectFace(heading: Int) {
        guard let faceContourDetector = self.faceContourDetector else {
            print ("Face contour detector is nil")
            return
        }
        guard let ciImage = self.lastImage else {
            print ("Last image not found")
            return
        }
        guard let uiImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: UIImage.Orientation.right).resized(toWidth: CGFloat(600)) else {
            print ("UIImage resize failed")
            return
        }
        faceContourDetector.detect(uiImage: uiImage, heading: heading)
    }
}

// Updates from rotation manager during user navigation to heading.
extension SkinToneDetectionSession: NavigateUserDelegate {
    func updatedHeadingValues(heading: Int) {
        // Update UI with heading value.
        DispatchQueue.main.async {
            self.headingLabel.text = "heading: " + String(heading)
        }
    }
    
    // Ask user to start rotating in given direction.
    func startRotation(direction: RotationManager.Direction, deltaDegrees: Int) {
        DispatchQueue.main.async {
            self.instructionLabel.text = self.expectedNavigationText(direction: direction)
            self.testLabel.text = "Diff: " + String(deltaDegrees)
        }
    }
    
    // Stop Rotation when user reaches target heading.
    func stopRotation() {
        DispatchQueue.main.async {
            self.instructionLabel.text = "Stop"
        }
    }
    
    private func expectedNavigationText(direction: RotationManager.Direction) -> String {
        if (direction == RotationManager.Direction.CLOCKWISE) {
            return "Rotate slowly to your right -->"
        }
        return "Rotate slowly to your left <---"
    }
}

// Updates for detected contours of given image.
extension SkinToneDetectionSession: FaceContourDelegate {
    func detectedContours(uiImage: UIImage, contourPoints: ContourPoints, heading: Int) {
        backendServiceQueue.async {
            if (self.currentFlow == CurrentFlow.NAVIGATION_PER_UPLOAD) {
                self.navigationPerUploadFlow(uiImage: uiImage, contourPoints: contourPoints)
            } else {
                self.rotationAndWalkingFlow(uiImage: uiImage, contourPoints: contourPoints, heading: heading)
            }
        }
    }
    
    func navigationPerUploadFlow(uiImage: UIImage, contourPoints: ContourPoints) {
        guard let backendService = self.backendService else {
            print ("Backend service not found")
            return
        }
        backendService.detectskinTone(sessionId: self.sessionId, uiImage: uiImage, contourPoints: contourPoints)
        
        // Display alert.
        DispatchQueue.main.async {
            let alert = Utils.createAlert(message: self.PROCESSING_ALERT)
            self.present(alert, animated: true)
        }
    }
    
    func rotationAndWalkingFlow(uiImage: UIImage, contourPoints: ContourPoints, heading: Int) {
        guard let userSessionService = userSessionService else {
            print ("UserSession service not found")
            return
        }
        if (userSessionService.uploadRotationImage(userSessionId: self.userSessionId, uiImage: uiImage, contourPoints: contourPoints, heading: heading)) {
            numRotationImagesSent += 1
            DispatchQueue.main.async {
                self.imagesSentLabel.text = String(self.numRotationImagesSent)
            }
        }
    }
}

// Responses from navigation per upload flow backend service.
extension SkinToneDetectionSession: SessionResponseHandler {
    func onSessionCreation(sessionId: String) {
        
        backendServiceQueue.async {
            self.sessionId = sessionId
            self.sessionState = SessionState.RUNNING
        }
        
        DispatchQueue.main.async {
            // Dismiss initialization alert.
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    func userNavigationInstruction(instruction: String) {
        backendServiceQueue.async {
            print ("End to End latency: \(Date().timeIntervalSince(self.pictureClickStartTime))")
            self.lastInstruction = instruction
            
            DispatchQueue.main.async {
                // Show navigation instruction in a UILabel here.
                // Dismiss processing alert.
                self.dismiss(animated: false, completion: nil)
            }
        }
    }
}

// Video frame handler.
extension SkinToneDetectionSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print ("Could not get CVImageBuffer from sample buffer")
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: cvImageBuffer)
        backendServiceQueue.async {
            self.lastImage = ciImage
        }
    }
}


class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

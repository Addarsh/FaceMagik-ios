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
    }
    
    // Class level constant to control which flow is triggered.
    enum CurrentFlow {
        case NAVIGATION_PER_UPLOAD
        case ROTATION_AND_WALKING
    }
    private let currentFlow = CurrentFlow.ROTATION_AND_WALKING
    
    // Outlets to Storyboard.
    @IBOutlet weak var sessionLabel: UILabel!
    @IBOutlet weak var navigationLabel: UILabel!
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
    var lastImageSampleBuffer: CMSampleBuffer?
    let PROCESSING_ALERT = "Processing..."
    let INTIALIZING_ALERT = "Initializing..."
    
    // User Session Service variables.
    var userSessionService: UserSessionService?
    var userSessionId = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        notifCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        backendService = BackendService(sessionResponseHandler: self)
        userSessionService = UserSessionService(userSessionServiceDelegate: self, is_remote_endpoint: false)
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
            } else {
                guard let userSessionService = self.userSessionService else {
                    print ("UserSession service not found")
                    return
                }
                userSessionService.createUserSession()
            }
        }
        
        // Display alert.
        let alert = Utils.createWaitingAlert(message: self.INTIALIZING_ALERT)
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
            guard let faceMaskDetector = self.faceContourDetector else {
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
                faceMaskDetector.detect(uiImage: uiImage)
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
    
    override func viewDidDisappear(_ animated: Bool) {
        captureSessionQueue.async {
            self.captureSession.stopRunning()
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
    
}

extension SkinToneDetectionSession: UserSessionServiceDelegate {
    
    func onSessionCreation(userSessionId: String) {
        backendServiceQueue.async {
            self.userSessionId = userSessionId
            self.sessionState = SessionState.USER_SESSION_CREATED
        }
        
        DispatchQueue.main.async {
            self.sessionLabel.text = "Session Started"
            // Dismiss initialization alert.
            self.dismiss(animated: false, completion: nil)
        }
    }
    
}

extension SkinToneDetectionSession: SessionResponseHandler {
    func onSessionCreation(sessionId: String) {
        
        backendServiceQueue.async {
            self.sessionId = sessionId
            self.sessionState = SessionState.RUNNING
        }
        
        DispatchQueue.main.async {
            self.sessionLabel.text = "Session Running"
            // Dismiss initialization alert.
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    func userNavigationInstruction(instruction: String) {
        backendServiceQueue.async {
            print ("End to End latency: \(Date().timeIntervalSince(self.pictureClickStartTime))")
            self.lastInstruction = instruction
            
            DispatchQueue.main.async {
                self.navigationLabel.text = instruction
                // Dismiss processing alert.
                self.dismiss(animated: false, completion: nil)
            }
        }
    }
}

// Delegate to detection of face contours.
extension SkinToneDetectionSession: FaceContourDelegate {
    func detectedContours(uiImage: UIImage, noseMiddePoint: [Int], faceTillNoseEndContourPoints: [[Int]], mouthWithoutLipsContourPoints: [[Int]], mouthWithLipsContourPoints: [[Int]], leftEyeContourPoints: [[Int]], rightEyeContourPoints: [[Int]], leftEyebrowContourPoints: [[Int]], rightEyebrowContourPoints: [[Int]]) {
        backendServiceQueue.async {
            guard let backendService = self.backendService else {
                print ("Backend service not found")
                return
            }
            backendService.detectskinTone(sessionId: self.sessionId, uiImage: uiImage, noseMiddePoint: noseMiddePoint, faceTillNoseEndContourPoints: faceTillNoseEndContourPoints, mouthWithoutLipsContourPoints: mouthWithoutLipsContourPoints, mouthWithLipsContourPoints: mouthWithLipsContourPoints, leftEyeContourPoints: leftEyeContourPoints, rightEyeContourPoints: rightEyeContourPoints, leftEyebrowContourPoints: leftEyebrowContourPoints, rightEyebrowContourPoints: rightEyebrowContourPoints)
            
            // Display alert.
            DispatchQueue.main.async {
                let alert = Utils.createWaitingAlert(message: self.PROCESSING_ALERT)
                self.present(alert, animated: true)
            }
        }
    }
}

extension SkinToneDetectionSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print ("Could not get CVImageBuffer from sample buffer")
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: cvImageBuffer)
        backendServiceQueue.async {
            self.lastImageSampleBuffer = sampleBuffer
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

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
    }
    
    // Outlets to Storyboard.
    @IBOutlet weak var sessionLabel: UILabel!
    @IBOutlet weak var navigationLabel: UILabel!
    @IBOutlet private var previewView: PreviewView!
    
    // Camera variables.
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let notifCenter = NotificationCenter.default
    private let captureSessionQueue = DispatchQueue(label: "user video queue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    private let videoOutputQueue = DispatchQueue(label: "output video frames queue")
    
    // Skin tone session variables.
    private let backendServiceQueue = DispatchQueue(label: "backend service queue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    var sessionState = SessionState.NOT_STARTED
    var backendService: BackendService?
    var sessionId = ""
    var lastInstruction = ""
    var lastImage: CIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        notifCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        backendService = BackendService(sessionResponseHandler: self)

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
    
    @IBAction func didTapButton(_ sender: UIButton) {
        backendServiceQueue.async {
            guard let backendService = self.backendService else {
                print ("Backend service not found")
                return
            }
            switch(self.sessionState) {
            case SessionState.NOT_STARTED:
                backendService.createSkinToneSession()
            case SessionState.RUNNING:
                guard let ciImage = self.lastImage else {
                    print ("Last image not found")
                    return
                }
                backendService.detectskinTone(sessionId: self.sessionId, ciImage: ciImage)
            case SessionState.COMPLETE:
                print ("Session complete")
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
    
}

extension SkinToneDetectionSession: SessionResponseHandler {
    func onSessionCreation(sessionId: String) {
        
        backendServiceQueue.async {
            self.sessionId = sessionId
            self.sessionState = SessionState.RUNNING
        }
        
        DispatchQueue.main.async {
            self.sessionLabel.text = "Session Running"
        }
    }
    
    func userNavigationInstruction(instruction: String) {
        backendServiceQueue.async {
            self.lastInstruction = instruction
            
            DispatchQueue.main.async {
                self.navigationLabel.text = instruction
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

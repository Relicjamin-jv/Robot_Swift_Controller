//
//  ViewController.swift
//  Controller
//
//  Created by Collin Campbell on 3/27/23.
//

import UIKit
import SwiftUI
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var photoView: UIImageView!
    @IBOutlet weak var debug: UILabel!
    
    private var bluetoothManager : BluetoothVM!
    
    private let rectSize = 170.0
    private let offsetPosVert = 0.0
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var maskLayer = CAShapeLayer()
    
    private var currentFrame: CVImageBuffer?
    
    @IBAction func takePhoto(_ sender: Any){
        photoView.contentMode = .scaleAspectFill
        var ciImage = CIImage(cvImageBuffer: currentFrame!)
        self.photoView.image = UIImage(ciImage: ciImage)
    }

    
    override func viewDidAppear(_ animated: Bool) {
        //session Start
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        DispatchQueue.global(qos: .background).async{
            self.captureSession.startRunning()
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        //session Stopped
        self.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
        self.captureSession.stopRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bluetoothManager = BluetoothVM(debug: debug)
        
        let offset: Double = rectSize/2
        let x_position = ((previewView.frame.width/2.0) - offset)
        let y_position = ((previewView.frame.height/2.0) - offset) - offsetPosVert
        maskLayer.frame = CGRect(origin: CGPoint(x: x_position, y: y_position), size: CGSize(width: rectSize, height: rectSize))
        
        self.setCameraInput()
        self.showCameraFeed()
        self.setCameraOutput()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.previewView.bounds
    }
    
    //MARK: Session initialisation and video output
    private func setCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .back).devices.first else {
            fatalError("No back camera device found.")
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.previewView.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.previewView.frame
    }
    
    private func setCameraOutput() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
              connection.isVideoOrientationSupported else { return }
        
        connection.videoOrientation = .portrait
    }
    
    //MARK: AVCaptureVideo Delegate
    func captureOutput(_ output: AVCaptureOutput,didOutput sampleBuffer: CMSampleBuffer,from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        
        // global frame var that gets updated every frame
        currentFrame = frame
        
        createRectLayer()
    }
    
    
    private func createRectLayer() {
        maskLayer.cornerRadius = 10
        maskLayer.opacity = 1
        maskLayer.borderColor = UIColor.systemBlue.cgColor
        maskLayer.borderWidth = 6.0
        previewLayer.insertSublayer(maskLayer, at: 1)
    }
    
    func removeMask() {
        maskLayer.removeFromSuperlayer()
    }
}

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}


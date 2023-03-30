//
//  ViewController.swift
//  Controller
//
//  Created by Collin Campbell on 3/27/23.
//

import UIKit
import SwiftUI
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var contouredImage: UIImage?
    
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
        let ciImage = CIImage(cvImageBuffer: currentFrame!)
        let cgImage = convertCIImage(inputImg: ciImage)
        detectVisionContours(image: UIImage(cgImage: cgImage!))
        self.photoView.image = contouredImage!
    }
    
    func convertCIImage(inputImg: CIImage) -> CGImage? {
        let context = CIContext()
        if let cgImage = context.createCGImage(inputImg, from: inputImg.extent){
            return cgImage
        }
        return nil
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
    
    // adding the coin reader functions
    func detectVisionContours(image: UIImage) {
        var points : String = ""
        let context = CIContext()
        let sourceImage =  image
        print(sourceImage)
        let inputImage = CIImage(cgImage: sourceImage.cgImage!)

            let contourRequest = VNDetectContoursRequest()
            contourRequest.revision = VNDetectContourRequestRevision1
            contourRequest.contrastAdjustment = 1.0
            contourRequest.detectDarkOnLight = true
            contourRequest.maximumImageDimension = 512

            let requestHandler = VNImageRequestHandler(ciImage: inputImage, options: [:])

            do {
                try requestHandler.perform([contourRequest])
                if let contoursObservation = contourRequest.results?.first as? VNContoursObservation {
                    points = String(contoursObservation.contourCount)
                    self.contouredImage = drawContours(contoursObservation: contoursObservation, sourceImage: sourceImage.cgImage!)

                    for i in 0..<contoursObservation.contourCount {
                        if let contour = try? contoursObservation.contour(at: i) as VNContour {
                            let boundingCircle = try VNGeometryUtils.boundingCircle(for: contour)
                            let diameter = boundingCircle.radius * 2
                            if diameter > 0.1 {
                                print("Bounding circle diameter for contour \(i+1): \(diameter)")
                            }
                        }
                    }
                }
            } catch {
                print("Error performing contour detection: \(error.localizedDescription)")
            }

       }
    }






    public func drawContours(contoursObservation: VNContoursObservation, sourceImage: CGImage) -> UIImage {
         let size = CGSize(width: sourceImage.width, height: sourceImage.height)
         let renderer = UIGraphicsImageRenderer(size: size)
         
         let renderedImage = renderer.image { (context) in
         let renderingContext = context.cgContext

         let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
         renderingContext.concatenate(flipVertical)

         renderingContext.draw(sourceImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
         
         renderingContext.scaleBy(x: size.width, y: size.height)
         renderingContext.setLineWidth(5.0 / CGFloat(size.width))
         let redUIColor = UIColor.red
         renderingContext.setStrokeColor(redUIColor.cgColor)
         renderingContext.addPath(contoursObservation.normalizedPath)
         renderingContext.strokePath()
         }
         
         return renderedImage
     }


extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}




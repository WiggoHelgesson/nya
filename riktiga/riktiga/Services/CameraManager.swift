import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine
import AudioToolbox

// MARK: - Camera Manager for Food Scanning

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    @Published var session = AVCaptureSession()
    @Published var scannableBarcode: String?
    @Published var capturedImage: UIImage?
    @Published var isCameraReady = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?
    
    private let sessionQueue = DispatchQueue(label: "com.upanddown.camera.sessionQueue")
    
    override init() {
        super.init()
        setupSession()
    }
    
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ No back camera found")
                return
            }
            self.device = videoDevice
            
            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                print("❌ Camera input error: \(error)")
                return
            }
            
            // Photo Output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            // Metadata Output (for barcodes)
            if self.session.canAddOutput(self.metadataOutput) {
                self.session.addOutput(self.metadataOutput)
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                self.metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr, .upce]
            }
            
            self.session.commitConfiguration()
            
            self.sessionQueue.async {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isCameraReady = true
                }
            }
        }
    }
    
    func setZoom(_ level: CGFloat) {
        guard let device = device else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(level, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
            self.zoomLevel = level
        } catch {
            print("❌ Zoom error: \(error)")
        }
    }
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Prevent duplicate triggers
            if scannableBarcode != stringValue {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                self.scannableBarcode = stringValue
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

// MARK: - Camera Manager Preview View

struct CameraManagerPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.frame
        }
    }
}


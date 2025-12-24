import SwiftUI
import AVFoundation
import PhotosUI
import Combine

struct LivePhotoCaptureView: View {
    @Binding var capturedImage: UIImage?
    var onCapture: (() -> Void)? = nil  // Callback when live photo is captured
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var cameraManager = DualCameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            // Main camera preview
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Camera position indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(cameraManager.currentPosition == .back ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(cameraManager.currentPosition == .back ? "Bakkamera" : "Framkamera")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Circle()
                            .fill(cameraManager.currentPosition == .front ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    .padding(.trailing, 16)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Capture status
                if isCapturing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(cameraManager.capturePhase)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                }
                
                Spacer()
                
                // Up&Down Live label
                Text("Up&Down Live")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                
                // Bottom controls
                HStack(spacing: 40) {
                    // Gallery button
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    
                    // Capture button
                    Button(action: startDualCapture) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(isCapturing ? Color.gray : Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .disabled(isCapturing)
                    
                    // Flip camera button
                    Button(action: {
                        cameraManager.flipCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .disabled(isCapturing)
                }
                .padding(.bottom, 50)
                .padding(.top, 20)
            }
        }
        .onAppear {
            cameraManager.checkPermissions()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let newValue,
                   let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        let finalImage = createSingleImageOverlay(image: image)
                        capturedImage = finalImage
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: cameraManager.combinedImage) { _, newImage in
            if let newImage {
                capturedImage = newImage
                onCapture?()  // Mark as Up&Down Live photo
                isCapturing = false
                dismiss()
            }
        }
    }
    
    private func startDualCapture() {
        isCapturing = true
        cameraManager.startDualCapture()
    }
    
    private func createSingleImageOverlay(image: UIImage) -> UIImage {
        // Use 4:3 aspect ratio to match dual camera format
        let size = CGSize(width: 1200, height: 900)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw image - no overlay, just the image
        drawImageFill(image, in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func drawImageFill(_ image: UIImage, in rect: CGRect) {
        let imageAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height
        
        var drawRect: CGRect
        if imageAspect > rectAspect {
            let newHeight = rect.height
            let newWidth = newHeight * imageAspect
            let xOffset = rect.origin.x + (rect.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: rect.origin.y, width: newWidth, height: newHeight)
        } else {
            let newWidth = rect.width
            let newHeight = newWidth / imageAspect
            let yOffset = rect.origin.y + (rect.height - newHeight) / 2
            drawRect = CGRect(x: rect.origin.x, y: yOffset, width: newWidth, height: newHeight)
        }
        
        image.draw(in: drawRect)
    }
    
}

// MARK: - Dual Camera Manager (Sequential Capture)

class DualCameraManager: NSObject, ObservableObject {
    @Published var combinedImage: UIImage?
    @Published var isAuthorized = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var capturePhase: String = ""
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    
    private var backImage: UIImage?
    private var frontImage: UIImage?
    private var isCapturingDual = false
    private var capturedFirstImage = false
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession(position: .back)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession(position: .back)
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    private func setupSession(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Add photo output if not already added
        if !session.outputs.contains(photoOutput) {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
        }
        
        session.commitConfiguration()
        
        DispatchQueue.main.async {
            self.currentPosition = position
        }
        
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }
    
    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        setupSession(position: newPosition)
    }
    
    func startDualCapture() {
        self.backImage = nil
        self.frontImage = nil
        self.isCapturingDual = true
        self.capturedFirstImage = false
        
        // Make sure we start with back camera
        if currentPosition != .back {
            setupSession(position: .back)
            // Wait for session to stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.capturePhoto(phase: "📸 Tar bild bakåt...")
            }
        } else {
            capturePhoto(phase: "📸 Tar bild bakåt...")
        }
    }
    
    private func capturePhoto(phase: String) {
        DispatchQueue.main.async {
            self.capturePhase = phase
        }
        
        // Small delay to ensure camera is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            // Check if we have a valid connection
            guard let connection = self.photoOutput.connection(with: .video), connection.isActive else {
                print("❌ No active video connection")
                DispatchQueue.main.async {
                    self.capturePhase = "❌ Kamerafel"
                    self.isCapturingDual = false
                }
                return
            }
            
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    private func createCombinedImage() {
        guard let backImage = backImage, let frontImage = frontImage else {
            print("❌ Missing images for combination")
            return
        }
        
        DispatchQueue.main.async {
            self.capturePhase = "🎨 Skapar bild..."
        }
        
        // Use 4:3 aspect ratio (1200x900) - works well with 300px height display
        let size = CGSize(width: 1200, height: 900)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw back image (main image) - fill entire canvas
        drawImageFill(backImage, in: CGRect(origin: .zero, size: size))
        
        // Draw front image (selfie) - positioned so it's visible when cropped
        let selfieWidth: CGFloat = 280
        let selfieHeight: CGFloat = 360
        let selfieRect = CGRect(
            x: 80,  // Moved right so it's fully visible in feed
            y: 40,
            width: selfieWidth,
            height: selfieHeight
        )
        
        // Draw shadow
        let shadowRect = selfieRect.offsetBy(dx: 4, dy: 4)
        UIColor.black.withAlphaComponent(0.5).setFill()
        UIBezierPath(roundedRect: shadowRect, cornerRadius: 20).fill()
        
        // Draw white border
        let borderRect = selfieRect.insetBy(dx: -4, dy: -4)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: borderRect, cornerRadius: 24).fill()
        
        // Clip and draw selfie
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        let clipPath = UIBezierPath(roundedRect: selfieRect, cornerRadius: 20)
        clipPath.addClip()
        drawImageFill(frontImage, in: selfieRect)
        context?.restoreGState()
        
        // NO stats or branding - just the two images!
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        
        DispatchQueue.main.async {
            self.combinedImage = finalImage
            self.isCapturingDual = false
            self.capturePhase = ""
        }
    }
    
    private func drawImageFill(_ image: UIImage, in rect: CGRect) {
        let imageAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height
        
        var drawRect: CGRect
        if imageAspect > rectAspect {
            let newHeight = rect.height
            let newWidth = newHeight * imageAspect
            let xOffset = rect.origin.x + (rect.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: rect.origin.y, width: newWidth, height: newHeight)
        } else {
            let newWidth = rect.width
            let newHeight = newWidth / imageAspect
            let yOffset = rect.origin.y + (rect.height - newHeight) / 2
            drawRect = CGRect(x: rect.origin.x, y: yOffset, width: newWidth, height: newHeight)
        }
        
        image.draw(in: drawRect)
    }
    
}

extension DualCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error)")
            DispatchQueue.main.async {
                self.capturePhase = "❌ Fel vid fotografering"
                self.isCapturingDual = false
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("❌ Could not get image data")
            return
        }
        
        if !capturedFirstImage {
            // First image captured (back camera)
            print("✅ Back camera image captured")
            backImage = image
            capturedFirstImage = true
            
            // Now switch to front camera and capture
            DispatchQueue.main.async {
                self.capturePhase = "🔄 Byter till framkamera..."
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.setupSession(position: .front)
                
                // Wait for front camera to be ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.capturePhoto(phase: "📸 Tar selfie...")
                }
            }
        } else {
            // Second image captured (front camera)
            print("✅ Front camera image captured")
            
            // Fix orientation for front camera (mirror)
            if let cgImage = image.cgImage {
                frontImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
            } else {
                frontImage = image
            }
            
            // Create combined image
            createCombinedImage()
            
            // Switch back to back camera for next time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.setupSession(position: .back)
            }
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = UIScreen.main.bounds
        }
    }
}

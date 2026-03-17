import SwiftUI
import AVFoundation
import PhotosUI
import Combine

struct LivePhotoCaptureView: View {
    @Binding var capturedImage: UIImage?
    var onCapture: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var cameraManager = DualCameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    private var titleText: String {
        if cameraManager.combinedImage != nil {
            return "Up&Down Live"
        } else if cameraManager.frontPreviewImage != nil {
            return L.t(sv: "Bild på din träning", nb: "Bilde av treningen din")
        } else {
            return L.t(sv: "Bild på dig", nb: "Bilde av deg")
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let combined = cameraManager.combinedImage {
                reviewScreen(image: combined)
            } else {
                cameraScreen
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
                        onCapture?()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Camera Screen
    
    private var cameraScreen: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
            
            VStack {
                // Top bar
                HStack {
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
                    
                    Text(titleText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(20)
                    
                    Spacer()
                    
                    if cameraManager.frontPreviewImage == nil {
                        Button(action: { cameraManager.flipCamera() }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                    } else {
                        Color.clear.frame(width: 42, height: 42)
                            .padding(.trailing, 16)
                    }
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 40) {
                    if cameraManager.frontPreviewImage == nil {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    } else {
                        Color.clear.frame(width: 56, height: 56)
                    }
                    
                    Button(action: handleCaptureButton) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    
                    Color.clear.frame(width: 56, height: 56)
                }
                .padding(.bottom, 50)
                .padding(.top, 20)
            }
            
            // Selfie overlay after first capture
            if let selfie = cameraManager.frontPreviewImage {
                VStack {
                    HStack {
                        Image(uiImage: selfie)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 2, y: 2)
                            .padding(.leading, 30)
                            .padding(.top, 130)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Review Screen
    
    private func reviewScreen(image: UIImage) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .padding(.leading, 16)
                
                Spacer()
                
                Text("Up&Down Live")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Color.clear.frame(width: 42, height: 42)
                    .padding(.trailing, 16)
            }
            .padding(.top, 60)
            
            Spacer()
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: {
                capturedImage = image
                onCapture?()
                dismiss()
            }) {
                Text(L.t(sv: "Publicera", nb: "Publiser"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Actions
    
    private func handleCaptureButton() {
        if cameraManager.frontPreviewImage == nil {
            cameraManager.captureFrontPhoto()
        } else {
            cameraManager.captureBackPhoto()
        }
    }
    
    private func createSingleImageOverlay(image: UIImage) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
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

// MARK: - Dual Camera Manager (Two-Tap Manual Capture)

class DualCameraManager: NSObject, ObservableObject {
    @Published var combinedImage: UIImage?
    @Published var isAuthorized = false
    @Published var currentPosition: AVCaptureDevice.Position = .front
    @Published var frontPreviewImage: UIImage?
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    
    private var backImage: UIImage?
    private var frontImage: UIImage?
    private var isCapturingFront = true
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession(position: .front)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession(position: .front)
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
        
        session.inputs.forEach { session.removeInput($0) }
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
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
    
    func captureFrontPhoto() {
        isCapturingFront = true
        frontImage = nil
        backImage = nil
        frontPreviewImage = nil
        capturePhoto()
    }
    
    func captureBackPhoto() {
        isCapturingFront = false
        capturePhoto()
    }
    
    private func capturePhoto() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            
            guard let connection = self.photoOutput.connection(with: .video), connection.isActive else {
                print("❌ No active video connection")
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
        
        let size = CGSize(width: 900, height: 1200)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        drawImageFill(backImage, in: CGRect(origin: .zero, size: size))
        
        let selfieWidth: CGFloat = 180
        let selfieHeight: CGFloat = 240
        let selfieRect = CGRect(
            x: 50,
            y: 60,
            width: selfieWidth,
            height: selfieHeight
        )
        
        let shadowRect = selfieRect.offsetBy(dx: 4, dy: 4)
        UIColor.black.withAlphaComponent(0.5).setFill()
        UIBezierPath(roundedRect: shadowRect, cornerRadius: 20).fill()
        
        let borderRect = selfieRect.insetBy(dx: -4, dy: -4)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: borderRect, cornerRadius: 24).fill()
        
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        let clipPath = UIBezierPath(roundedRect: selfieRect, cornerRadius: 20)
        clipPath.addClip()
        drawImageFill(frontImage, in: selfieRect)
        context?.restoreGState()
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        
        DispatchQueue.main.async {
            self.combinedImage = finalImage
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
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("❌ Could not get image data")
            return
        }
        
        if isCapturingFront {
            print("✅ Front camera (selfie) captured")
            
            if let cgImage = image.cgImage {
                frontImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
            } else {
                frontImage = image
            }
            
            DispatchQueue.main.async {
                self.frontPreviewImage = self.frontImage
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.setupSession(position: .back)
            }
        } else {
            print("✅ Back camera (training) captured")
            backImage = image
            createCombinedImage()
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

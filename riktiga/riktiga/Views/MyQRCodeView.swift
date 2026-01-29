import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

struct MyQRCodeView: View {
    let userId: String
    let userName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: QRTab = .myQR
    @State private var qrCodeImage: UIImage?
    @State private var scannedUserId: String?
    @State private var showUserProfile = false
    @State private var cameraPermissionDenied = false
    
    enum QRTab {
        case myQR
        case scanQR
    }
    
    // Deep link URL for the profile
    private var profileDeepLink: String {
        "upanddown://profile/\(userId)"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 32) {
                    TabButton(title: "Min QR", isSelected: selectedTab == .myQR) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .myQR
                        }
                    }
                    
                    TabButton(title: "Skanna QR", isSelected: selectedTab == .scanQR) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .scanQR
                        }
                    }
                }
                .padding(.top, 20)
                
                // Content based on selected tab
                if selectedTab == .myQR {
                    myQRContent
                } else {
                    scanQRContent
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
    }
    
    // MARK: - My QR Content
    private var myQRContent: some View {
        VStack(spacing: 24) {
            // Description text
            Text("Användare kan lägga till dig som vän genom att skanna den här koden")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 24)
            
            // QR Code Card
            VStack(spacing: 20) {
                // QR Code with logo overlay
                ZStack {
                    if let qrImage = qrCodeImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                    } else {
                        // Placeholder while generating
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: 220, height: 220)
                            .overlay(ProgressView())
                    }
                    
                    // App logo in center
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        )
                }
                
                // User name
                Text(userName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black, Color(white: 0.5), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
            )
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Scan QR Content
    private var scanQRContent: some View {
        VStack(spacing: 24) {
            Text("Skanna en väns QR-kod för att lägga till dem")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 24)
            
            // Camera view
            ZStack {
                if cameraPermissionDenied {
                    // Permission denied state
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .frame(height: 400)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("Kameraåtkomst nekad")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Aktivera kameraåtkomst i Inställningar för att skanna QR-koder")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("Öppna Inställningar")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                        )
                } else {
                    // QR Scanner camera view
                    QRScannerView(
                        onCodeScanned: { code in
                            handleScannedCode(code)
                        },
                        onPermissionDenied: {
                            cameraPermissionDenied = true
                        }
                    )
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // Scanning overlay
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(height: 400)
                    
                    // Scanning frame
                    VStack {
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.black, Color(white: 0.5), Color.black],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 200, height: 200)
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    // MARK: - Generate QR Code
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        // Create QR code data
        let data = Data(profileDeepLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction for logo overlay
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    // MARK: - Camera Permission
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            cameraPermissionDenied = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        default:
            cameraPermissionDenied = false
        }
    }
    
    // MARK: - Handle Scanned Code
    private func handleScannedCode(_ code: String) {
        // Parse the deep link: upanddown://profile/{userId}
        if code.hasPrefix("upanddown://profile/") {
            let scannedId = String(code.dropFirst("upanddown://profile/".count))
            print("✅ Scanned user ID: \(scannedId)")
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Navigate to profile or show confirmation
            scannedUserId = scannedId
            showUserProfile = true
        }
    }
}

// MARK: - QR Scanner View (UIKit wrapper)
struct QRScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onPermissionDenied: () -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        controller.onPermissionDenied = onPermissionDenied
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCodeScanned: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?
    private var hasScanned = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if status == .denied || status == .restricted {
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionDenied?()
            }
            return
        }
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let captureSession = captureSession else {
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                return
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds
            
            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
            
        } catch {
            print("❌ Error setting up camera: \(error)")
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned else { return }
        
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            
            hasScanned = true
            
            // Stop scanning temporarily
            captureSession?.stopRunning()
            
            onCodeScanned?(stringValue)
            
            // Resume scanning after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.hasScanned = false
                DispatchQueue.global(qos: .userInitiated).async {
                    self?.captureSession?.startRunning()
                }
            }
        }
    }
}

// MARK: - Tab Button
private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .gray)
                
                // Underline indicator
                Rectangle()
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.black, Color(white: 0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MyQRCodeView(userId: "test-user-123", userName: "Wiggo Helgesson")
}

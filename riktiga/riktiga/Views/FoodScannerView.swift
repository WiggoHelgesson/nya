import SwiftUI
import AVFoundation
import Vision
import PhotosUI
import Combine
import Supabase

// MARK: - Scan Mode
enum FoodScanMode: String, CaseIterable {
    case ai = "Scanna mat"
    case barcode = "Streckkod"
    case foodLabel = "Näringstabell"
    
    var icon: String {
        switch self {
        case .ai: return "apple.logo" // Will use custom SF Symbol or image
        case .barcode: return "barcode"
        case .foodLabel: return "doc.text.fill"
        }
    }
    
    var displayIcon: String {
        switch self {
        case .ai: return "🍎" // Food emoji for AI scan
        case .barcode: return "barcode"
        case .foodLabel: return "doc.text.fill"
        }
    }
}

// MARK: - Food Scanner View
struct FoodScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = FoodScannerViewModel()
    @ObservedObject private var analyzingManager = AnalyzingFoodManager.shared
    @State private var selectedMode: FoodScanMode
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var flashEnabled = false
    @State private var zoomLevel: CGFloat = 1.0
    
    init(initialMode: FoodScanMode = .ai) {
        _selectedMode = State(initialValue: initialMode)
    }
    
    var body: some View {
        ZStack {
            // Camera Preview
            FoodScannerCameraPreview(session: viewModel.session)
                .ignoresSafeArea()
            
            // Darkened overlay with cutout
            overlayWithCutout
            
            // UI Elements
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Zoom selector
                zoomSelector
                    .padding(.bottom, 20)
                
                // Mode selector
                modeSelector
                    .padding(.bottom, 16)
                
                // Bottom controls
                bottomControls
                    .padding(.bottom, 40)
            }
            
            // Loading overlay
            if viewModel.isAnalyzing {
                analyzingOverlay
            }
            
            // Result overlay
            if let result = viewModel.scanResult {
                resultOverlay(result: result)
            }
        }
        .onAppear {
            viewModel.startSession()
            viewModel.scanMode = selectedMode
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .onChange(of: selectedMode) { _, newMode in
            viewModel.scanMode = newMode
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            if let item = newItem {
                Task {
                    if selectedMode == .ai {
                        // For AI mode, load image and send to AnalyzingManager
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                AnalyzingFoodManager.shared.startAnalyzing(image: image)
                                dismiss()
                            }
                        }
                    } else {
                        await viewModel.processSelectedPhoto(item)
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Overlay with Cutout
    private var overlayWithCutout: some View {
        GeometryReader { geometry in
            let cutoutSize = cutoutSize(for: selectedMode, in: geometry.size)
            let cutoutRect = CGRect(
                x: (geometry.size.width - cutoutSize.width) / 2,
                y: (geometry.size.height - cutoutSize.height) / 2 - 50,
                width: cutoutSize.width,
                height: cutoutSize.height
            )
            
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                // Cutout (clear area)
                Rectangle()
                    .frame(width: cutoutSize.width, height: cutoutSize.height)
                    .position(x: cutoutRect.midX, y: cutoutRect.midY)
                    .blendMode(.destinationOut)
                
                // Corner brackets
                cornerBrackets(rect: cutoutRect, mode: selectedMode)
            }
            .compositingGroup()
        }
    }
    
    private func cutoutSize(for mode: FoodScanMode, in size: CGSize) -> CGSize {
        let padding: CGFloat = 40
        let width = size.width - (padding * 2)
        
        switch mode {
        case .ai:
            return CGSize(width: width, height: width * 1.2) // Tall rectangle for food
        case .barcode:
            return CGSize(width: width, height: width * 0.5) // Wide rectangle for barcode
        case .foodLabel:
            return CGSize(width: width, height: width * 1.4) // Taller for nutrition label
        }
    }
    
    private func cornerBrackets(rect: CGRect, mode: FoodScanMode) -> some View {
        let cornerLength: CGFloat = 30
        let lineWidth: CGFloat = 4
        let cornerRadius: CGFloat = mode == .barcode ? 16 : 20
        
        return ZStack {
            // Top left
            CornerBracket(corner: .topLeft, length: cornerLength, lineWidth: lineWidth, radius: cornerRadius)
                .position(x: rect.minX + cornerLength/2, y: rect.minY + cornerLength/2)
            
            // Top right
            CornerBracket(corner: .topRight, length: cornerLength, lineWidth: lineWidth, radius: cornerRadius)
                .position(x: rect.maxX - cornerLength/2, y: rect.minY + cornerLength/2)
            
            // Bottom left
            CornerBracket(corner: .bottomLeft, length: cornerLength, lineWidth: lineWidth, radius: cornerRadius)
                .position(x: rect.minX + cornerLength/2, y: rect.maxY - cornerLength/2)
            
            // Bottom right
            CornerBracket(corner: .bottomRight, length: cornerLength, lineWidth: lineWidth, radius: cornerRadius)
                .position(x: rect.maxX - cornerLength/2, y: rect.maxY - cornerLength/2)
        }
        .foregroundColor(.white)
    }
    
    // MARK: - Zoom Selector
    private var zoomSelector: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { zoomLevel = 0.5 }
                viewModel.setZoom(0.5)
            } label: {
                Text(".5x")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(zoomLevel == 0.5 ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(zoomLevel == 0.5 ? Color.white : Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
            
            Button {
                withAnimation { zoomLevel = 1.0 }
                viewModel.setZoom(1.0)
            } label: {
                Text("1x")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(zoomLevel == 1.0 ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(zoomLevel == 1.0 ? Color.white : Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Mode Selector
    private var modeSelector: some View {
        HStack(spacing: 8) {
            ForEach(FoodScanMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 6) {
                        modeIcon(for: mode)
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedMode == mode ? .black : .white)
                    .frame(width: 100, height: 65)
                    .background(selectedMode == mode ? Color.white : Color.black.opacity(0.4))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Bottom Controls
    @ViewBuilder
    private func modeIcon(for mode: FoodScanMode) -> some View {
        switch mode {
        case .ai:
            // Custom food scan icon with apple
            ZStack {
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .medium))
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .offset(x: 10, y: -8)
            }
        case .barcode:
            Image(systemName: "barcode")
                .font(.system(size: 18))
        case .foodLabel:
            Image(systemName: "doc.text.fill")
                .font(.system(size: 18))
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: 50) {
            // Flash toggle
            Button {
                flashEnabled.toggle()
                viewModel.toggleFlash(flashEnabled)
            } label: {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }
            
            // Capture button
            Button {
                captureAndDismissIfAI()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(viewModel.isCameraReady ? Color.white : Color.white.opacity(0.5))
                        .frame(width: 58, height: 58)
                }
            }
            .disabled(!viewModel.isCameraReady)
            
            // Photo library
            Button {
                showPhotosPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }
        }
    }
    
    // MARK: - Capture and Dismiss for AI Mode
    private func captureAndDismissIfAI() {
        if selectedMode == .ai {
            // For AI mode, capture photo and immediately dismiss
            viewModel.capturePhotoForExternalAnalysis { image in
                if let image = image {
                    // Start analyzing with the shared manager
                    AnalyzingFoodManager.shared.startAnalyzing(image: image)
                }
                // Dismiss to go back to Home
                dismiss()
            }
        } else {
            // For other modes, use normal flow
            viewModel.capturePhoto()
        }
    }
    
    // MARK: - Analyzing Overlay
    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Analyserar...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(viewModel.analysisStatus)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Result Overlay
    private func resultOverlay(result: FoodScanResult) -> some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.clearResult()
                }
            
            VStack(spacing: 20) {
                // Food image if available
                if let image = result.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(16)
                }
                
                // Food name
                Text(result.foodName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Nutrition info
                HStack(spacing: 30) {
                    NutritionBadge(value: "\(result.calories)", label: "kcal", color: .orange)
                    NutritionBadge(value: "\(result.protein)g", label: "Protein", color: .red)
                    NutritionBadge(value: "\(result.carbs)g", label: "Kolhydrat", color: .yellow)
                    NutritionBadge(value: "\(result.fat)g", label: "Fett", color: .blue)
                }
                
                // Serving size
                if let serving = result.servingSize {
                    Text("Portionsstorlek: \(serving)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Confidence
                if let confidence = result.confidence {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("AI-konfidens: \(Int(confidence * 100))%")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        viewModel.clearResult()
                    } label: {
                        Text("Skanna igen")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 140, height: 50)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(25)
                    }
                    
                    Button {
                        viewModel.addToLog(result)
                        dismiss()
                    } label: {
                        Text("Lägg till")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 140, height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                    }
                }
                .padding(.top, 10)
            }
            .padding(30)
        }
    }
}

// MARK: - Corner Bracket Shape
struct CornerBracket: View {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let corner: Corner
    let length: CGFloat
    let lineWidth: CGFloat
    let radius: CGFloat
    
    var body: some View {
        Path { path in
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: radius))
                path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
            case .topRight:
                path.move(to: CGPoint(x: length - length, y: 0))
                path.addLine(to: CGPoint(x: length - radius, y: 0))
                path.addQuadCurve(to: CGPoint(x: length, y: radius), control: CGPoint(x: length, y: 0))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: length - radius))
                path.addQuadCurve(to: CGPoint(x: radius, y: length), control: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: length, y: length))
            case .bottomRight:
                path.move(to: CGPoint(x: length, y: 0))
                path.addLine(to: CGPoint(x: length, y: length - radius))
                path.addQuadCurve(to: CGPoint(x: length - radius, y: length), control: CGPoint(x: length, y: length))
                path.addLine(to: CGPoint(x: 0, y: length))
            }
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        .frame(width: length, height: length)
    }
}

// MARK: - Nutrition Badge
struct NutritionBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 70)
    }
}

// MARK: - Food Scanner Camera Preview View
struct FoodScannerCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Food Scan Result
struct FoodScanResult {
    let foodName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let servingSize: String?
    let confidence: Double?
    let image: UIImage?
    let barcode: String?
}

// MARK: - Food Scanner ViewModel
class FoodScannerViewModel: NSObject, ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisStatus = ""
    @Published var scanResult: FoodScanResult?
    @Published var scanMode: FoodScanMode = .ai
    @Published var isCameraReady = false
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?
    private var capturedImage: UIImage?
    
    // Barcode detection
    private var barcodeRequest: VNDetectBarcodesRequest?
    private var lastBarcodeDetectionTime: Date = .distantPast
    
    // External analysis callback
    private var externalCaptureCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        setupBarcodeDetection()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ No camera available")
            return
        }
        
        currentDevice = device
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .photo
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            }
        } catch {
            print("❌ Camera setup error: \(error)")
        }
    }
    
    private func setupBarcodeDetection() {
        barcodeRequest = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self,
                  self.scanMode == .barcode,
                  let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first,
                  let payload = barcode.payloadStringValue else { return }
            
            // Debounce barcode detection
            let now = Date()
            guard now.timeIntervalSince(self.lastBarcodeDetectionTime) > 2.0 else { return }
            self.lastBarcodeDetectionTime = now
            
            DispatchQueue.main.async {
                self.lookupBarcode(payload)
            }
        }
    }
    
    func startSession() {
        guard !session.isRunning else {
            DispatchQueue.main.async { [weak self] in
                self?.isCameraReady = true
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Setup camera on background thread
            self.setupCamera()
            
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isCameraReady = true
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.main.async { [weak self] in
            self?.isCameraReady = false
        }
        
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(factor * 2, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("❌ Zoom error: \(error)")
        }
    }
    
    func toggleFlash(_ enabled: Bool) {
        guard let device = currentDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("❌ Flash error: \(error)")
        }
    }
    
    func capturePhoto() {
        // Ensure session is running and we have an active connection
        guard session.isRunning else {
            print("❌ Cannot capture: session not running")
            return
        }
        
        guard let connection = photoOutput.connection(with: .video), connection.isActive else {
            print("❌ Cannot capture: no active video connection")
            return
        }
        
        externalCaptureCompletion = nil // Normal capture
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func capturePhotoForExternalAnalysis(completion: @escaping (UIImage?) -> Void) {
        // Ensure session is running and we have an active connection
        guard session.isRunning else {
            print("❌ Cannot capture: session not running")
            completion(nil)
            return
        }
        
        guard let connection = photoOutput.connection(with: .video), connection.isActive else {
            print("❌ Cannot capture: no active video connection")
            completion(nil)
            return
        }
        
        externalCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func processSelectedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        
        await MainActor.run {
            capturedImage = image
            processImage(image)
        }
    }
    
    private func processImage(_ image: UIImage) {
        capturedImage = image
        
        switch scanMode {
        case .ai:
            analyzeWithAI(image)
        case .barcode:
            detectBarcodeInImage(image)
        case .foodLabel:
            analyzeNutritionLabel(image)
        }
    }
    
    // MARK: - AI Food Analysis
    private func analyzeWithAI(_ image: UIImage) {
        isAnalyzing = true
        analysisStatus = "Skickar till AI..."
        
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "ImageError", code: -1)
                }
                
                let base64Image = imageData.base64EncodedString()
                
                await MainActor.run {
                    analysisStatus = "AI analyserar maten..."
                }
                
                let result = try await sendToGPTVision(base64Image: base64Image, analysisType: .food)
                
                await MainActor.run {
                    scanResult = FoodScanResult(
                        foodName: result.name,
                        calories: result.calories,
                        protein: result.protein,
                        carbs: result.carbs,
                        fat: result.fat,
                        servingSize: result.servingSize,
                        confidence: result.confidence,
                        image: image,
                        barcode: nil
                    )
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    analysisStatus = "Fel: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
    
    // MARK: - Nutrition Label Analysis
    private func analyzeNutritionLabel(_ image: UIImage) {
        isAnalyzing = true
        analysisStatus = "Läser näringstabell..."
        
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageError", code: -1)
                }
                
                let base64Image = imageData.base64EncodedString()
                
                await MainActor.run {
                    analysisStatus = "AI analyserar näringstabellen..."
                }
                
                let result = try await sendToGPTVision(base64Image: base64Image, analysisType: .nutritionLabel)
                
                await MainActor.run {
                    scanResult = FoodScanResult(
                        foodName: result.name,
                        calories: result.calories,
                        protein: result.protein,
                        carbs: result.carbs,
                        fat: result.fat,
                        servingSize: result.servingSize,
                        confidence: result.confidence,
                        image: image,
                        barcode: nil
                    )
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    analysisStatus = "Fel: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
    
    // MARK: - Barcode Lookup
    private func lookupBarcode(_ barcode: String) {
        isAnalyzing = true
        analysisStatus = "Söker produkt: \(barcode)..."
        
        Task {
            // Try Open Food Facts first
            if let product = await searchOpenFoodFacts(barcode: barcode) {
                await MainActor.run {
                    scanResult = product
                    isAnalyzing = false
                }
                return
            }
            
            await MainActor.run {
                analysisStatus = "Produkten hittades inte"
                isAnalyzing = false
            }
        }
    }
    
    private func searchOpenFoodFacts(barcode: String) async -> FoodScanResult? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode)?fields=code,product_name,brands,nutriments,serving_size,image_front_url") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("UpAndDown iOS App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int, status == 1,
                  let product = json["product"] as? [String: Any] else {
                return nil
            }
            
            let name = product["product_name"] as? String ?? "Okänd produkt"
            let brand = product["brands"] as? String
            let servingSize = product["serving_size"] as? String
            
            var calories = 0
            var protein = 0
            var carbs = 0
            var fat = 0
            
            if let nutriments = product["nutriments"] as? [String: Any] {
                calories = Int(nutriments["energy-kcal_100g"] as? Double ?? 0)
                protein = Int(nutriments["proteins_100g"] as? Double ?? 0)
                carbs = Int(nutriments["carbohydrates_100g"] as? Double ?? 0)
                fat = Int(nutriments["fat_100g"] as? Double ?? 0)
            }
            
            let displayName = brand != nil ? "\(name) (\(brand!))" : name
            
            return FoodScanResult(
                foodName: displayName,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                servingSize: servingSize ?? "100g",
                confidence: nil,
                image: nil,
                barcode: barcode
            )
        } catch {
            print("❌ Barcode lookup error: \(error)")
            return nil
        }
    }
    
    private func detectBarcodeInImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first,
                  let payload = barcode.payloadStringValue else {
                DispatchQueue.main.async {
                    self?.analysisStatus = "Ingen streckkod hittades"
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.lookupBarcode(payload)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Barcode detection error: \(error)")
        }
    }
    
    // MARK: - GPT Vision API
    enum AnalysisType {
        case food
        case nutritionLabel
    }
    
    struct GPTAnalysisResult {
        let name: String
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let servingSize: String?
        let confidence: Double?
    }
    
    private func sendToGPTVision(base64Image: String, analysisType: AnalysisType) async throws -> GPTAnalysisResult {
        guard let apiKey = EnvManager.shared.value(for: "OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw NSError(domain: "APIKeyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not found"])
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "URLError", code: -1)
        }
        
        let prompt: String
        switch analysisType {
        case .food:
            prompt = """
            Analysera denna bild av mat. Identifiera vad för mat det är och uppskatta näringsvärden per portion.
            
            Svara ENDAST med JSON i detta format (inga andra tecken):
            {
                "name": "Namn på maten på svenska",
                "calories": 0,
                "protein": 0,
                "carbs": 0,
                "fat": 0,
                "serving_size": "Uppskattad portionsstorlek",
                "confidence": 0.0
            }
            
            - calories, protein, carbs, fat ska vara heltal
            - confidence ska vara mellan 0.0 och 1.0
            - Om du inte kan identifiera maten, gissa baserat på vad du ser
            """
        case .nutritionLabel:
            prompt = """
            Läs av denna näringstabell/nutrition label och extrahera informationen.
            
            Svara ENDAST med JSON i detta format (inga andra tecken):
            {
                "name": "Produktnamn om synligt, annars 'Produkt'",
                "calories": 0,
                "protein": 0,
                "carbs": 0,
                "fat": 0,
                "serving_size": "Portionsstorlek från etiketten",
                "confidence": 0.0
            }
            
            - Värden ska vara per 100g eller per portion (ange i serving_size)
            - calories, protein, carbs, fat ska vara heltal
            - confidence ska vara mellan 0.0 och 1.0
            """
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "ParseError", code: -1)
        }
        
        // Extract JSON from response (remove markdown if present)
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let resultData = cleanContent.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw NSError(domain: "JSONError", code: -1)
        }
        
        return GPTAnalysisResult(
            name: result["name"] as? String ?? "Okänd mat",
            calories: result["calories"] as? Int ?? 0,
            protein: result["protein"] as? Int ?? 0,
            carbs: result["carbs"] as? Int ?? 0,
            fat: result["fat"] as? Int ?? 0,
            servingSize: result["serving_size"] as? String,
            confidence: result["confidence"] as? Double
        )
    }
    
    func clearResult() {
        scanResult = nil
        capturedImage = nil
    }
    
    func addToLog(_ result: FoodScanResult) {
        Task {
            do {
                guard let userId = try? await SupabaseConfig.supabase.auth.session.user.id.uuidString else {
                    print("❌ No user logged in")
                    return
                }
                
                let entry = FoodLogInsert(
                    id: UUID().uuidString,
                    userId: userId,
                    name: result.foodName,
                    calories: result.calories,
                    protein: result.protein,
                    carbs: result.carbs,
                    fat: result.fat,
                    mealType: "snack",
                    loggedAt: ISO8601DateFormatter().string(from: Date())
                )
                
                try await SupabaseConfig.supabase
                    .from("food_logs")
                    .insert(entry)
                    .execute()
                
                print("✅ Added to log: \(result.foodName) - \(result.calories) kcal")
                
                // Notify HomeView to refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFoodLogs"), object: nil)
                }
            } catch {
                print("❌ Error saving to log: \(error)")
            }
        }
    }
}

// MARK: - Food Log Insert Model
struct FoodLogInsert: Codable {
    let id: String
    let userId: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let mealType: String
    let loggedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case userId = "user_id"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension FoodScannerViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            // Call completion with nil if failed
            DispatchQueue.main.async {
                self.externalCaptureCompletion?(nil)
                self.externalCaptureCompletion = nil
            }
            return
        }
        
        DispatchQueue.main.async {
            // Check if there's an external completion handler
            if let completion = self.externalCaptureCompletion {
                completion(image)
                self.externalCaptureCompletion = nil
            } else {
                // Normal flow
                self.processImage(image)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension FoodScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard scanMode == .barcode,
              !isAnalyzing,
              let barcodeRequest = barcodeRequest,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([barcodeRequest])
        } catch {
            // Silent fail for continuous scanning
        }
    }
}

#Preview {
    FoodScannerView()
}

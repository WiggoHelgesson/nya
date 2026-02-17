import SwiftUI

struct ProductAnalysisLoadingView: View {
    let onAnalysisComplete: (ProductHealthAnalysis) -> Void
    let onScanAnother: () -> Void
    let onDismissScanner: () -> Void
    let barcode: String
    
    @State private var currentStep = 0
    @State private var showBottomText = false
    @State private var analysis: ProductHealthAnalysis?
    @State private var error: String?
    @State private var analysisFinished = false
    @State private var pulseAnimation = false
    @State private var showResult = false
    
    private let steps: [(icon: String, text: String)] = [
        ("barcode.viewfinder", "Läser streckkod"),
        ("magnifyingglass", "Söker i databaser"),
        ("flask", "Analyserar ingredienser"),
        ("exclamationmark.triangle", "Upptäcker tillsatser"),
        ("chart.bar", "Bygger hälsobetyg"),
        ("doc.text.magnifyingglass", "Förbereder rapport")
    ]
    
    var body: some View {
        ZStack {
            if showResult, let analysis = analysis {
                // Show result directly inside the same cover -- no white flash
                ProductHealthResultView(
                    analysis: analysis,
                    onScanAnother: {
                        onScanAnother()
                    },
                    onDismiss: {
                        onDismissScanner()
                    }
                )
                .transition(.opacity)
            } else {
                loadingContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showResult)
        .interactiveDismissDisabled(true)
        .statusBarHidden(!showResult)
        .task {
            await runAnalysis()
        }
    }
    
    // MARK: - Loading Content
    
    private var loadingContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)
                
                // Top icon
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 3)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 16)
                
                Text("Analyserar produkt")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 50)
                
                // Steps list
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepRow(index: index, icon: step.icon, text: step.text)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Bottom text or error
                bottomContent
            }
        }
    }
    
    @ViewBuilder
    private var bottomContent: some View {
        if let error = error {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                
                Text("Något gick fel")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Stäng") {
                    onDismissScanner()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 60)
        } else {
            VStack(spacing: 6) {
                if currentStep >= steps.count && !analysisFinished {
                    ProgressView()
                        .tint(.green)
                        .scaleEffect(1.2)
                        .padding(.bottom, 8)
                    
                    Text("Slutför analys...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .opacity(pulseAnimation ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                } else {
                    Text("Identifierar din produkt...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Vänligen vänta")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .opacity(showBottomText ? 1 : 0)
            .padding(.bottom, 60)
        }
    }
    
    @ViewBuilder
    private func stepRow(index: Int, icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(index < currentStep ? Color.green : (index == currentStep ? Color.green.opacity(0.2) : Color.white.opacity(0.1)))
                    .frame(width: 44, height: 44)
                
                if index < currentStep {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(index == currentStep ? .green : .gray)
                }
            }
            
            Text(text)
                .font(.system(size: 17, weight: index <= currentStep ? .semibold : .regular))
                .foregroundColor(index <= currentStep ? .white : .gray)
            
            Spacer()
            
            if index == currentStep && !analysisFinished {
                ProgressView()
                    .tint(.green)
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Analysis + Animation Logic
    
    private func runAnalysis() async {
        withAnimation { showBottomText = true }
        
        // Start GPT analysis in parallel
        let analysisTask = Task { () -> ProductHealthAnalysis in
            try await ProductHealthService.shared.analyzeBarcode(barcode)
        }
        
        // Step animation: each step waits longer so the animation stretches
        // to fill the real loading time. We check if GPT is done between steps.
        // Total if GPT takes long: ~2s + ~2.5s + ~3s + ~3s + ~3s + ~3s = ~16.5s max
        // If GPT finishes early, remaining steps speed through at 0.4s each.
        let stepDelays: [UInt64] = [
            2_000_000_000,  // Step 0: "Läser streckkod" - 2s
            2_500_000_000,  // Step 1: "Söker i databaser" - 2.5s
            3_000_000_000,  // Step 2: "Analyserar ingredienser" - 3s
            3_000_000_000,  // Step 3: "Upptäcker tillsatser" - 3s
            3_000_000_000,  // Step 4: "Bygger hälsobetyg" - 3s
            3_000_000_000,  // Step 5: "Förbereder rapport" - 3s
        ]
        
        for stepIndex in 0..<steps.count {
            let totalDelay = analysisFinished ? 400_000_000 : stepDelays[stepIndex]
            
            // Split the delay into chunks so we can check if analysis finished
            let chunkSize: UInt64 = 200_000_000 // Check every 0.2s
            var elapsed: UInt64 = 0
            
            while elapsed < totalDelay {
                try? await Task.sleep(nanoseconds: chunkSize)
                elapsed += chunkSize
                
                // If analysis just finished, speed through remaining delay
                if analysisFinished && elapsed >= 400_000_000 {
                    break
                }
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = stepIndex + 1
                }
            }
        }
        
        // All visual steps done - show pulse if still waiting
        if !analysisFinished {
            await MainActor.run {
                pulseAnimation = true
            }
        }
        
        // Wait for GPT result
        do {
            let result = try await analysisTask.value
            await MainActor.run {
                analysisFinished = true
                analysis = result
            }
            
            // Complete final step visually if needed
            if currentStep < steps.count {
                for remaining in currentStep..<steps.count {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = remaining + 1
                        }
                    }
                }
            }
            
            // Brief pause then show result
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                // Save to food log
                onAnalysisComplete(result)
                // Show result directly in this view
                showResult = true
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                analysisFinished = true
            }
        }
    }
}

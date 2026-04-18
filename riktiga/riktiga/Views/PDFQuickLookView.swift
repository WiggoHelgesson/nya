import SwiftUI
import QuickLook
import UIKit

/// SwiftUI wrapper around QLPreviewController for displaying a PDF from a local URL.
/// Download the remote PDF to a temp file first, then present this view in a sheet.
struct PDFQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}

/// Downloads a signed URL into a temp file and presents it via QuickLook.
struct RemotePDFViewer: View {
    let signedUrl: URL
    let displayName: String

    @Environment(\.dismiss) private var dismiss
    @State private var localUrl: URL?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if let localUrl {
                    PDFQuickLookView(url: localUrl)
                        .ignoresSafeArea()
                } else if let errorText {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button(L.t(sv: "Försök igen", nb: "Prøv igjen")) {
                            Task { await download() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { dismiss() }
                }
            }
            .task { await download() }
        }
    }

    private func download() async {
        await MainActor.run {
            errorText = nil
            localUrl = nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: signedUrl)
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "shipping-label-\(UUID().uuidString).pdf"
            let destination = tempDir.appendingPathComponent(filename)
            try data.write(to: destination, options: .atomic)
            await MainActor.run { localUrl = destination }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
            }
        }
    }
}

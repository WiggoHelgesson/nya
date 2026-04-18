import PhotosUI
import SwiftUI

struct SellCameraView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath
    var onAbandonFlow: () -> Void

    @StateObject private var camera = SellCameraSession()
    @State private var photoPickerItems: [PhotosPickerItem] = []

    private let maxPhotos = 5
    private let minPhotos = 2

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(L.t(sv: "Kameratillstånd behövs för att ta bilder.", nb: "Kameratilgang kreves for å ta bilder."))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                Spacer()

                instructionBlock
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                bottomStrip
                controlsRow
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            camera.onCapturedImage = { image in
                guard model.images.count < maxPhotos else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    model.images.append(image)
                }
            }
            camera.requestAccessAndConfigure()
        }
        .onDisappear {
            camera.stopSession()
        }
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await importPickedPhotos(newItems) }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                onAbandonFlow()
            } label: {
                Text(L.t(sv: "Stäng", nb: "Lukk"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private var instructionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.white)
                Text(L.t(sv: "AI-assistent", nb: "AI-assistent"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(L.t(
                sv: "Ta minst 2 bilder (eller välj från galleriet), gärna upp till 5. Välj olika vinklar och detaljer som visar skick och märke.",
                nb: "Ta minst 2 bilder (eller velg fra galleriet), gjerne opptil 5. Velg ulike vinkler og detaljer som viser stand og merke."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomStrip: some View {
        HStack(spacing: 10) {
            ForEach(0..<maxPhotos, id: \.self) { index in
                stripSlot(index: index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .animation(.easeOut(duration: 0.22), value: model.images.count)
    }

    @ViewBuilder
    private func stripSlot(index: Int) -> some View {
        let has = index < model.images.count
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(has ? 0.14 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
            if has {
                Image(uiImage: model.images[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
        .frame(width: 58, height: 58)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            if model.images.isEmpty {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button {
                    _ = withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        model.images.removeLast()
                    }
                } label: {
                    Text(L.t(sv: "Ångra", nb: "Angre"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(minWidth: 52, minHeight: 44)
                }
            }

            let slotsLeft = max(0, maxPhotos - model.images.count)
            PhotosPicker(
                selection: $photoPickerItems,
                maxSelectionCount: max(1, min(slotsLeft, maxPhotos)),
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .disabled(slotsLeft == 0)
            .opacity(slotsLeft > 0 ? 1 : 0.35)

            Spacer(minLength: 8)

            Button {
                camera.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.95), lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                }
            }
            .disabled(!camera.isReady || model.images.count >= maxPhotos)
            .opacity((camera.isReady && model.images.count < maxPhotos) ? 1 : 0.45)

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    path.append(SellRoute.category)
                }
            } label: {
                Text(L.t(sv: "Klart", nb: "Ferdig"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(model.images.count >= minPhotos ? Color.white : .white.opacity(0.35))
                    .frame(width: 72, height: 44)
            }
            .disabled(model.images.count < minPhotos)
        }
        .padding(.horizontal, 16)
    }

    private func importPickedPhotos(_ items: [PhotosPickerItem]) async {
        var additions: [UIImage] = []
        additions.reserveCapacity(items.count)
        for item in items {
            guard additions.count + model.images.count < maxPhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                additions.append(image)
            }
        }
        await MainActor.run {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                for img in additions where model.images.count < maxPhotos {
                    model.images.append(img)
                }
            }
            photoPickerItems = []
        }
    }
}

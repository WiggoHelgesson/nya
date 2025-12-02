import SwiftUI
import Combine
import UIKit
import MapKit
import CoreLocation

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var showStartSession = false
    @State private var showResumeSession = false
    @State private var selectedTab = 0  // 0=Hem, 1=Zon krig, 2=Start, 3=Belöningar, 4=Profil
    @State private var previousTab = 0
    @State private var autoPresentedActiveSession = false
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private var startTabIcon: Image {
        if let uiImage = UIImage(systemName: "play.fill")?.withTintColor(.black, renderingMode: .alwaysOriginal) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "play.fill")
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: Binding(
                get: { selectedTab },
                set: { newValue in
                    if newValue == 2 {
                        triggerHeavyHaptic()
                        Task {
                            await TrackingPermissionManager.shared.requestPermissionIfNeeded()
                            await MainActor.run {
                                if sessionManager.hasActiveSession {
                                    showResumeSession = true
                                } else {
                                    showStartSession = true
                                }
                            }
                        }
                        selectedTab = previousTab
                    } else {
                        if newValue != selectedTab {
                            triggerHeavyHaptic()
                        }
                        previousTab = newValue
                        selectedTab = newValue
                    }
                }
            )) {
                SocialView()
                    .tag(0)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Hem")
                    }
                
                ZoneWarView()
                    .tag(1)
                    .tabItem {
                        Image(systemName: "map.fill")
                        Text("Zon krig")
                    }
                
                Color.clear
                    .tag(2)
                    .tabItem {
                        VStack(spacing: 4) {
                            startTabIcon
                            Text("Starta pass")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                
                RewardsView()
                    .tag(3)
                    .tabItem {
                        Image(systemName: "gift.fill")
                        Text("Belöningar")
                    }
                
                ProfileView()
                    .tag(4)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profil")
                    }
            }
            .accentColor(.black)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .enableSwipeBack()
        .fullScreenCover(isPresented: $showStartSession) {
            GymSessionView()
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showResumeSession) {
            StartSessionView()
                .ignoresSafeArea()
        }
        .onAppear {
            if sessionManager.hasActiveSession && !showStartSession && !showResumeSession {
                autoPresentedActiveSession = true
                showResumeSession = true
            }
            hapticGenerator.prepare()
        }
        .onChange(of: showStartSession) { _, newValue in
            if newValue {
                showResumeSession = false
            }
        }
        .onChange(of: showResumeSession) { _, newValue in
            if newValue {
                showStartSession = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSocial"))) { _ in
            selectedTab = 0
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseStartSession"))) { _ in
            showStartSession = false
            showResumeSession = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionFinalized"))) { _ in
            showStartSession = false
            showResumeSession = false
            autoPresentedActiveSession = false
        }
        .sheet(isPresented: $authViewModel.showUsernameRequiredPopup) {
            UsernameRequiredView().environmentObject(authViewModel)
        }
        .sheet(isPresented: $authViewModel.showPaywallAfterSignup) {
            PaywallAfterSignupView().environmentObject(authViewModel)
        }
        .onChange(of: sessionManager.hasActiveSession) { _, newValue in
            if newValue {
                if !autoPresentedActiveSession && !showStartSession && !showResumeSession {
                    autoPresentedActiveSession = true
                    showResumeSession = true
                }
            } else {
                autoPresentedActiveSession = false
            }
        }
    }
    
    private func triggerHeavyHaptic() {
        hapticGenerator.prepare()
        hapticGenerator.impactOccurred(intensity: 1.0)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

// MARK: - Transparent Start Session Container

private struct TransparentStartSessionContainer<Content: View>: View {
    var onDismiss: (() -> Void)?
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                    onDismiss?()
                }
            
            content
                .padding(.horizontal, 20)
        }
        .background(TransparentBackgroundView())
    }
}

private struct TransparentBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Global Swipe-Back Support

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            enableGesture(for: controller, coordinator: context.coordinator)
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            enableGesture(for: uiViewController, coordinator: context.coordinator)
        }
    }
    
    private func enableGesture(for controller: UIViewController, coordinator: Coordinator) {
        if let navigationController = controller.navigationController {
            applyGesture(on: navigationController, coordinator: coordinator)
        }
        
        if let window = controller.view.window {
            applyGestureRecursively(from: window.rootViewController, coordinator: coordinator)
        }
    }
    
    private func applyGesture(on navigationController: UINavigationController, coordinator: Coordinator) {
        navigationController.interactivePopGestureRecognizer?.delegate = coordinator
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    private func applyGestureRecursively(from root: UIViewController?, coordinator: Coordinator) {
        guard let root else { return }
        if let nav = root as? UINavigationController {
            applyGesture(on: nav, coordinator: coordinator)
        }
        for child in root.children {
            applyGestureRecursively(from: child, coordinator: coordinator)
        }
        if let presented = root.presentedViewController {
            applyGestureRecursively(from: presented, coordinator: coordinator)
        }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackEnabler())
    }
}

// MARK: - Zone War

struct ZoneWarView: View {
    @ObservedObject private var territoryStore = TerritoryStore.shared
    
    var body: some View {
        ZoneWarMapView(territories: territoryStore.territories)
            .ignoresSafeArea(edges: .bottom)
            .task {
                await territoryStore.refresh()
            }
            .refreshable {
                await territoryStore.refresh()
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zon krig")
                        .font(.system(size: 26, weight: .bold))
                    Text(territorySubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.thinMaterial)
                )
                .padding()
            }
    }
    
    private var territorySubtitle: String {
        let count = territoryStore.territories.count
        if count == 0 {
            return "Spring en slinga för att ta din första zon."
        } else if count == 1 {
            return "Du äger 1 zon."
        } else {
            return "Du äger \(count) zoner."
        }
    }
}

private struct ZoneWarMapView: UIViewRepresentable {
    let territories: [Territory]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .mutedStandard
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.update(uiView, territories: territories)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        private var hasCentered = false
        
        func update(_ mapView: MKMapView, territories: [Territory]) {
            mapView.removeOverlays(mapView.overlays)
            
            let polygons: [MKPolygon] = territories.flatMap { territory -> [MKPolygon] in
                territory.polygons.compactMap { ring in
                    guard ring.count >= 3 else { return nil }
                    var coords = ring
                    return coords.withUnsafeMutableBufferPointer { buffer in
                        let polygon = MKPolygon(coordinates: buffer.baseAddress!, count: ring.count)
                        polygon.title = territory.activity?.rawValue
                        return polygon
                    }
                }
            }
            
            mapView.addOverlays(polygons)
            
            if !hasCentered {
                if let first = polygons.first {
                    mapView.setVisibleMapRect(
                        first.boundingMapRect,
                        edgePadding: UIEdgeInsets(top: 120, left: 60, bottom: 160, right: 60),
                        animated: false
                    )
                } else {
                    let stockholm = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                    )
                    mapView.setRegion(stockholm, animated: false)
                }
                hasCentered = true
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.lineWidth = 2
            renderer.strokeColor = polygon.activityColor
            renderer.fillColor = polygon.activityColor.withAlphaComponent(0.25)
            return renderer
        }
    }
}


import SwiftUI
import UIKit

// MARK: - Global Swipe-Back Support

struct SwipeBackEnabler: UIViewControllerRepresentable {
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


import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    static let networkRestoredNotification = Notification.Name("NetworkMonitor.networkRestored")
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    enum ConnectionType: String {
        case wifi, cellular, wiredEthernet, unknown
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var wasDisconnected = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            let connected = path.status == .satisfied
            let type: ConnectionType = {
                if path.usesInterfaceType(.wifi) { return .wifi }
                if path.usesInterfaceType(.cellular) { return .cellular }
                if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
                return .unknown
            }()
            
            let isExpensive = path.isExpensive
            let isConstrained = path.isConstrained
            let supportsDNS = path.supportsDNS
            let supportsIPv4 = path.supportsIPv4
            let supportsIPv6 = path.supportsIPv6
            
            let shouldNotify = connected && self.wasDisconnected
            self.wasDisconnected = !connected
            
            DispatchQueue.main.async {
                self.isConnected = connected
                self.connectionType = type
                
                if shouldNotify {
                    NotificationCenter.default.post(name: Self.networkRestoredNotification, object: nil)
                }
                
                #if DEBUG
                if shouldNotify {
                    print("🌐 [NET] Network restored (\(type.rawValue)) — notifying observers")
                }
                print("🌐 [NET] Status: \(path.status), type: \(type.rawValue)")
                print("🌐 [NET] expensive: \(isExpensive), constrained: \(isConstrained), DNS: \(supportsDNS)")
                print("🌐 [NET] IPv4: \(supportsIPv4), IPv6: \(supportsIPv6)")
                #endif
            }
        }
        monitor.start(queue: queue)
    }
}

import Foundation

final class UppyUsageTracker {
    static let shared = UppyUsageTracker()
    
    private let chatCountKey = "uppy_chat_count"
    
    private init() {}
    
    var chatCount: Int {
        UserDefaults.standard.integer(forKey: chatCountKey)
    }
    
    func incrementChatCount() {
        let newValue = chatCount + 1
        UserDefaults.standard.set(newValue, forKey: chatCountKey)
    }
    
    func resetChatCount() {
        UserDefaults.standard.removeObject(forKey: chatCountKey)
    }
}







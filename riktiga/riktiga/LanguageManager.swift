import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable {
    case swedish = "sv"
    case norwegian = "nb"
    
    var displayName: String {
        switch self {
        case .swedish: return "Svenska"
        case .norwegian: return "Norsk"
        }
    }
    
    var flag: String {
        switch self {
        case .swedish: return "🇸🇪"
        case .norwegian: return "🇳🇴"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("app_language") var currentLanguage: AppLanguage = .swedish {
        didSet { objectWillChange.send() }
    }
}

enum L {
    static func t(sv: String, nb: String) -> String {
        LanguageManager.shared.currentLanguage == .norwegian ? nb : sv
    }
}

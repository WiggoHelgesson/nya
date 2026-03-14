import Foundation
import Supabase

class SupabaseConfig {
    static let projectURL = URL(string: "https://api.upanddownapp.com")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYmF0a29kdmlxZ2twc2J5dWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY2MzIsImV4cCI6MjA1OTg5MjYzMn0.e4W2ut1w_AHiQ_Uhi3HmEXdeGIe4eX-ZhgvIqU_ld6Q"
    
    static let storageBaseURL = "\(projectURL.absoluteString)/storage/v1/object/public"
    
    static func rewriteURL(_ urlString: String) -> String {
        let result = urlString.replacingOccurrences(
            of: "https://xebatkodviqgkpsbyuiv.supabase.co",
            with: projectURL.absoluteString
        )
        #if DEBUG
        if result != urlString {
            print("🔄 [REWRITE] \(urlString.prefix(80)) → \(result.prefix(80))")
        }
        #endif
        return result
    }
    
    static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: config)
    }()
    
    static let supabase = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey,
        options: .init(
            global: .init(session: urlSession)
        )
    )
    
    static func diagnoseConnection() {
        let start = Date()
        let host = projectURL.host ?? "?"
        
        print("═══════════════════════════════════════════")
        print("🔍 [DIAG] Supabase connection diagnostic")
        print("🔍 [DIAG] Host: \(host)")
        print("🔍 [DIAG] Network: \(NetworkMonitor.shared.connectionType.rawValue), connected: \(NetworkMonitor.shared.isConnected)")
        print("═══════════════════════════════════════════")
        
        // Step 1: DNS resolution check
        DispatchQueue.global(qos: .utility).async {
            let dnsHost = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            CFHostStartInfoResolution(dnsHost, .addresses, nil)
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(dnsHost, &success)?.takeUnretainedValue() as NSArray? {
                for case let addr as NSData in addresses {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let data = addr as Data
                    data.withUnsafeBytes { ptr in
                        let sockaddr = ptr.bindMemory(to: sockaddr.self).baseAddress!
                        getnameinfo(sockaddr, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    }
                    let ipString = String(cString: hostname)
                    if !ipString.isEmpty {
                        print("🌐 [DIAG] DNS resolved \(host) → \(ipString)")
                        if ipString == "146.112.61.110" {
                            print("🚨 [DIAG] ⚠️ SINKHOLE IP DETECTED — Telenor DNS is still blocking!")
                        }
                    }
                }
            } else {
                print("❌ [DIAG] DNS resolution FAILED for \(host)")
            }
        }
        
        // Step 2: HTTP connectivity test
        let url = projectURL.appendingPathComponent("/rest/v1/")
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = 10
        
        urlSession.dataTask(with: req) { data, response, error in
            let elapsed = Date().timeIntervalSince(start)
            if let error = error {
                let nsError = error as NSError
                print("❌ [DIAG] HTTP FAILED after \(String(format: "%.1f", elapsed))s")
                print("❌ [DIAG] Error: \(nsError.localizedDescription)")
                print("❌ [DIAG] Domain: \(nsError.domain), Code: \(nsError.code)")
                if nsError.code == -1001 {
                    print("❌ [DIAG] → TIMEOUT — server unreachable or DNS blocked")
                } else if nsError.code == -1200 {
                    print("❌ [DIAG] → TLS ERROR — likely connecting to wrong IP (DNS sinkhole)")
                } else if nsError.code == -1003 {
                    print("❌ [DIAG] → HOST NOT FOUND — DNS failed completely")
                }
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("❌ [DIAG] Underlying: \(underlying.domain) \(underlying.code) — \(underlying.localizedDescription)")
                }
                return
            }
            if let http = response as? HTTPURLResponse {
                print("✅ [DIAG] HTTP OK — \(http.statusCode) in \(String(format: "%.1f", elapsed))s")
            }
        }.resume()
        
        // Step 3: Storage connectivity test
        let storageURL = URL(string: "\(storageBaseURL)/avatars/")!
        var storageReq = URLRequest(url: storageURL)
        storageReq.timeoutInterval = 10
        
        urlSession.dataTask(with: storageReq) { _, response, error in
            let elapsed = Date().timeIntervalSince(start)
            if let error = error {
                let nsError = error as NSError
                print("❌ [DIAG] Storage FAILED: \(nsError.domain) \(nsError.code) — \(nsError.localizedDescription)")
            } else if let http = response as? HTTPURLResponse {
                print("✅ [DIAG] Storage OK — HTTP \(http.statusCode) in \(String(format: "%.1f", elapsed))s")
            }
        }.resume()
    }
}

import Foundation
import Supabase

class SupabaseConfig {
    static let projectURL = URL(string: "https://xebatkodviqgkpsbyuiv.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYmF0a29kdmlxZ2twc2J5dWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY2MzIsImV4cCI6MjA1OTg5MjYzMn0.e4W2ut1w_AHiQ_Uhi3HmEXdeGIe4eX-ZhgvIqU_ld6Q"
    
    static let supabase = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey
    )
}

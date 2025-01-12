import Supabase
import Foundation

struct SupabaseConfig {
    static let supabaseClient = SupabaseClient(
        supabaseURL: URL(string: "https://nnntecgqwirykozugdtw.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ubnRlY2dxd2lyeWtvenVnZHR3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY2MzkzODksImV4cCI6MjA1MjIxNTM4OX0.wn8qCayBo1W2gRoJgSIRnLdHAs5P2UgdE634msgOKbw"
    )
}


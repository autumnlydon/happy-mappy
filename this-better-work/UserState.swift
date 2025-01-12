import Foundation
import Supabase
import Auth

class UserState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: Auth.User?
    @Published var session: Auth.User?
    
    static let shared = UserState()
    private let client = SupabaseConfig.supabaseClient
    
    private init() {
        // Check for existing session
        Task {
            do {
                let session = try await client.auth.session
                await MainActor.run {
                    self.session = session.user
                    self.isAuthenticated = session.user != nil
                }
            } catch {
                print("No existing session")
                await MainActor.run {
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    @MainActor
    func signIn(email: String, password: String) async throws {
        do {
            // Perform sign-in and receive an AuthResponse
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            // Update application's state with the session
            self.session = authResponse.user
            self.isAuthenticated = authResponse.user != nil
        } catch {
            // Handle any errors that occurred during sign-in
            print("Error during sign-in: \(error)")
            throw error
        }
    }

    @MainActor
    func signUp(email: String, password: String) async throws {
        let authResponse = try await client.auth.signUp(
            email: email,
            password: password
        )
        self.session = authResponse.user
        self.isAuthenticated = authResponse.user != nil
    }
    
    @MainActor
    func signOut() async throws {
        try await client.auth.signOut()
        self.session = nil
        self.isAuthenticated = false
    }
} 

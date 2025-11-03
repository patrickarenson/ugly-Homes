//
//  ContentView.swift
//  Ugly Homes
//
//  Created by Patrick Arenson on 10/30/25.
//

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @State private var showResetPassword = false
    @State private var showResetSuccess = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordView(showSuccess: $showResetSuccess)
        }
        .alert("Password Reset Complete", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your password has been successfully reset. You can now log in with your new password.")
        }
        .onAppear {
            checkAuthStatus()
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: .supabaseAuthStateChanged)) { _ in
            checkAuthStatus()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    func checkAuthStatus() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                print("✅ Session found! User: \(session.user.id)")
                isAuthenticated = true
            } catch {
                print("❌ No session: \(error.localizedDescription)")
                isAuthenticated = false
            }
            isLoading = false
        }
    }

    func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")

        // Check if it's a reset password link
        if url.host == "reset-password" || url.path.contains("reset-password") {
            print("🔑 Password reset link detected")

            // Handle Supabase auth session from URL
            Task {
                do {
                    try await SupabaseManager.shared.client.auth.session(from: url)
                    print("✅ Auth session established from URL")

                    // Show reset password screen
                    await MainActor.run {
                        showResetPassword = true
                    }
                } catch {
                    print("❌ Error handling auth URL: \(error)")
                }
            }
        }
    }
}

extension Foundation.Notification.Name {
    static let supabaseAuthStateChanged = Foundation.Notification.Name("supabaseAuthStateChanged")
}

#Preview {
    ContentView()
}

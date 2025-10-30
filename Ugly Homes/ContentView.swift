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
        .onAppear {
            checkAuthStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .supabaseAuthStateChanged)) { _ in
            checkAuthStatus()
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
}

extension Notification.Name {
    static let supabaseAuthStateChanged = Notification.Name("supabaseAuthStateChanged")
}

#Preview {
    ContentView()
}

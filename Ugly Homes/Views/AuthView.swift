//
//  AuthView.swift
//  Ugly Homes
//
//  Authentication View
//

import SwiftUI
import Supabase

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            // Logo/Title
            VStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Ugly Homes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.bottom, 40)

            // Input fields
            VStack(spacing: 16) {
                if isSignUp {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: username) { oldValue, newValue in
                            // Automatically convert to lowercase
                            username = newValue.lowercased()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            // Error message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            // Auth button
            Button(action: handleAuth) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(isSignUp ? "Sign Up" : "Log In")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.orange)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading)

            // Toggle between sign up and login
            Button(action: {
                isSignUp.toggle()
                errorMessage = ""
            }) {
                Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding(.top, 60)
    }

    func handleAuth() {
        errorMessage = ""
        isLoading = true

        Task {
            do {
                if isSignUp {
                    // Convert username to lowercase
                    let lowercaseUsername = username.lowercased()

                    // Check if username already exists (case-insensitive)
                    print("🔍 Checking if username '\(lowercaseUsername)' is available...")
                    let existingProfiles: [Profile] = try await SupabaseManager.shared.client
                        .from("profiles")
                        .select()
                        .ilike("username", pattern: lowercaseUsername)
                        .execute()
                        .value

                    if !existingProfiles.isEmpty {
                        isLoading = false
                        errorMessage = "Username '\(lowercaseUsername)' is already taken. Please choose another."
                        print("❌ Username already exists")
                        return
                    }

                    print("✅ Username is available!")

                    // Sign up with metadata (profile will be auto-created by trigger)
                    let response = try await SupabaseManager.shared.client.auth.signUp(
                        email: email,
                        password: password,
                        data: [
                            "username": .string(lowercaseUsername),
                            "full_name": .string("")
                        ]
                    )

                    print("✅ Sign up successful! User ID: \(response.user.id)")

                    // Give the trigger a moment to create the profile
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                } else {
                    // Log in
                    let response = try await SupabaseManager.shared.client.auth.signIn(
                        email: email,
                        password: password
                    )

                    print("✅ Login successful! User ID: \(response.user.id)")
                }

                isLoading = false
                NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)

            } catch {
                isLoading = false
                print("❌ Auth error: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthView()
}

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
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.65, blue: 0.3),  // Orange
                    Color(red: 1.0, green: 0.45, blue: 0.2)   // Deeper orange
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    // Housers Logo
                    Image("HousersLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                    Text("housers")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

                    Text("Discover ugly homes, beautiful deals")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 50)

                // Auth card
                VStack(spacing: 20) {
                    // Input fields
                    VStack(spacing: 14) {
                        if isSignUp {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onChange(of: username) { oldValue, newValue in
                                        username = newValue.lowercased()
                                    }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }

                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            SecureField("Password", text: $password)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }

                    // Error message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
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
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.2, blue: 0.25),
                                Color.black
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .disabled(isLoading)

                    // Toggle between sign up and login
                    Button(action: {
                        isSignUp.toggle()
                        errorMessage = ""
                    }) {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(.white.opacity(0.9))
                            Text(isSignUp ? "Log In" : "Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
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

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
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    @State private var biometricType: BiometricType = .none
    @State private var hasSavedCredentials = false
    @State private var showSaveBiometricPrompt = false
    @State private var rememberMe = true  // Default to true

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

                // Logo - Bigger and centered
                VStack(spacing: 0) {
                    // Housers Logo (transparent background)
                    Image("HousersLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)

                    Text("The Social Marketplace for Real Estate")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.95))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .offset(y: -60)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

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

                    // Remember Me checkbox (only on login)
                    if !isSignUp {
                        HStack {
                            Button(action: {
                                rememberMe.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(.system(size: 20))
                                    Text("Remember me")
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(.system(size: 14))
                                }
                            }
                            Spacer()
                        }
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

                    // Biometric login button
                    if !isSignUp && hasSavedCredentials && biometricType != .none {
                        Button(action: handleBiometricAuth) {
                            HStack {
                                Image(systemName: biometricType.icon)
                                    .font(.system(size: 20))
                                Text("Sign in with \(biometricType.name)")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    }

                    // Forgot password (only show on login)
                    if !isSignUp {
                        Button(action: {
                            showForgotPassword = true
                        }) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .underline()
                        }
                    }

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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(showResetSuccess: $showResetSuccess)
        }
        .alert("Password Reset Email Sent", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your email for a link to reset your password.")
        }
        .alert("Save Login?", isPresented: $showSaveBiometricPrompt) {
            Button("Yes") {
                saveBiometricCredentials()
            }
            Button("Not Now", role: .cancel) {
                // Trigger auth state change even if they decline
                NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
            }
        } message: {
            Text("Would you like to use \(biometricType.name) to sign in next time?")
        }
        .onAppear {
            checkBiometricAvailability()
            loadSavedCredentials()
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

                    // Save credentials if Remember Me is checked
                    if rememberMe {
                        saveCredentials()
                    } else {
                        clearSavedCredentials()
                    }

                    // Prompt to save credentials if biometric is available and not already saved
                    await MainActor.run {
                        isLoading = false
                        if biometricType != .none && !hasSavedCredentials {
                            showSaveBiometricPrompt = true
                        } else {
                            // Only trigger auth state change if not showing biometric prompt
                            NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
                        }
                    }
                    return // Don't continue to the code below
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

    func checkBiometricAvailability() {
        biometricType = BiometricAuthManager.shared.biometricType()
        hasSavedCredentials = BiometricAuthManager.shared.getCredentials() != nil
        print("🔐 Biometric type: \(biometricType.name), Has credentials: \(hasSavedCredentials)")
    }

    func handleBiometricAuth() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                // Authenticate with biometrics
                let success = try await BiometricAuthManager.shared.authenticate()

                if success {
                    // Get stored credentials
                    guard let credentials = BiometricAuthManager.shared.getCredentials() else {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "Failed to retrieve credentials"
                        }
                        return
                    }

                    print("🔐 Biometric auth successful, signing in...")

                    // Sign in with stored credentials
                    let response = try await SupabaseManager.shared.client.auth.signIn(
                        email: credentials.email,
                        password: credentials.password
                    )

                    print("✅ Biometric login successful! User ID: \(response.user.id)")

                    await MainActor.run {
                        isLoading = false
                        NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Authentication failed"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ Biometric auth error: \(error)")
                    errorMessage = "Authentication failed. Please use your password."
                }
            }
        }
    }

    func saveBiometricCredentials() {
        let success = BiometricAuthManager.shared.saveCredentials(email: email, password: password)
        if success {
            print("✅ Credentials saved for biometric auth")
            hasSavedCredentials = true
        } else {
            print("❌ Failed to save credentials")
        }
        // Trigger auth state change after user responds to prompt
        NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
    }

    // MARK: - Remember Me Functions

    func saveCredentials() {
        UserDefaults.standard.set(email, forKey: "savedEmail")
        UserDefaults.standard.set(password, forKey: "savedPassword")
        UserDefaults.standard.set(true, forKey: "rememberMe")
        print("💾 Credentials saved for Remember Me")
    }

    func loadSavedCredentials() {
        if let savedEmail = UserDefaults.standard.string(forKey: "savedEmail"),
           let savedPassword = UserDefaults.standard.string(forKey: "savedPassword"),
           UserDefaults.standard.bool(forKey: "rememberMe") {
            email = savedEmail
            password = savedPassword
            rememberMe = true
            print("✅ Loaded saved credentials")
        }
    }

    func clearSavedCredentials() {
        UserDefaults.standard.removeObject(forKey: "savedEmail")
        UserDefaults.standard.removeObject(forKey: "savedPassword")
        UserDefaults.standard.set(false, forKey: "rememberMe")
        print("🗑️ Cleared saved credentials")
    }
}

#Preview {
    AuthView()
}

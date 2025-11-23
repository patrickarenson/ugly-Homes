//
//  AuthView.swift
//  Ugly Homes
//
//  Authentication View
//

import SwiftUI
import Supabase
import AuthenticationServices

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
    @State private var showTermsOfService = false
    @State private var agreedToTerms = false
    @State private var acceptedTermsCheckbox = false

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

                    // Terms of Service checkbox (only on signup)
                    if isSignUp {
                        HStack(alignment: .top, spacing: 8) {
                            Button(action: {
                                acceptedTermsCheckbox.toggle()
                            }) {
                                Image(systemName: acceptedTermsCheckbox ? "checkmark.square.fill" : "square")
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.system(size: 20))
                            }

                            Button(action: {
                                showTermsOfService = true
                            }) {
                                Text("I agree to the Terms of Service")
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.system(size: 14))
                                    .underline()
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()
                        }
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
                    .opacity((isSignUp && !acceptedTermsCheckbox) ? 0.5 : 1.0)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .disabled(isLoading || (isSignUp && !acceptedTermsCheckbox))

                    // OR divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                        Text("OR")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)

                    // Social login buttons
                    // Google Sign In
                    Button(action: { handleSocialLogin(provider: .google) }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            Text("Continue with Google")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
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
                        acceptedTermsCheckbox = false
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
        .onTapGesture {
            hideKeyboard()
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
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView(agreedToTerms: $acceptedTermsCheckbox) {
                // Just dismiss - checkbox is already updated
                showTermsOfService = false
            }
        }
        .onAppear {
            checkBiometricAvailability()
            loadSavedCredentials()
        }
    }

    func handleAuth() {
        errorMessage = ""
        isLoading = true

        if isSignUp {
            // For signup, proceed directly
            Task {
                do {
                    // Convert username to lowercase
                    let lowercaseUsername = username.lowercased()

                    // CONTENT MODERATION - Check username for inappropriate content
                    let usernameModeration = ContentModerationManager.shared.moderateText(lowercaseUsername)
                    switch usernameModeration {
                    case .blocked(let reason):
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "Username contains inappropriate content. Please choose a different username."
                        }
                        print("🚫 Username blocked: \(reason)")
                        return

                    case .flaggedForReview:
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "Username contains inappropriate content. Please choose a different username."
                        }
                        print("⚠️ Username flagged")
                        return

                    case .approved:
                        break
                    }

                    // Check if username already exists (case-insensitive)
                    print("🔍 Checking if username '\(lowercaseUsername)' is available...")
                    let existingProfiles: [Profile] = try await SupabaseManager.shared.client
                        .from("profiles")
                        .select()
                        .ilike("username", pattern: lowercaseUsername)
                        .execute()
                        .value

                    if !existingProfiles.isEmpty {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = "Username '\(lowercaseUsername)' is already taken. Please choose another."
                        }
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

                    // Save terms acceptance
                    try await saveTermsAcceptance(userId: response.user.id)

                    // Give the trigger a moment to create the profile
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    await MainActor.run {
                        isLoading = false
                        NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)

                        // Request push notification permission
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                print("✅ Push notifications enabled")
                            } else {
                                print("⚠️ Push notifications declined")
                            }
                        }
                    }

                } catch {
                    await MainActor.run {
                        isLoading = false
                        print("❌ Signup error: \(error)")
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // For login, proceed normally
            performLogin()
        }
    }

    func performLogin() {
        isLoading = true

        Task {
            do {
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

                    // Request push notification permission
                    NotificationManager.shared.requestPermission { granted in
                        if granted {
                            print("✅ Push notifications enabled")
                        } else {
                            print("⚠️ Push notifications declined")
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ Login error: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func handleSocialLogin(provider: Provider) {
        errorMessage = ""
        isLoading = true

        Task {
            do {
                // Construct OAuth URL for ASWebAuthenticationSession
                let supabaseURL = "https://pgezrygzubjieqfzyccy.supabase.co"
                let redirectURL = "houser://oauth-callback"
                let authURL = URL(string: "\(supabaseURL)/auth/v1/authorize?provider=\(provider.rawValue.lowercased())&redirect_to=\(redirectURL)")!

                print("🔑 Opening OAuth URL: \(authURL)")

                // Use ASWebAuthenticationSession for in-app authentication
                await MainActor.run {
                    let contextProvider = ASWebAuthenticationPresentationContextProvider()

                    let session = ASWebAuthenticationSession(
                        url: authURL,
                        callbackURLScheme: "houser"
                    ) { callbackURL, error in
                        Task {
                            if let error = error {
                                print("❌ OAuth session error: \(error)")
                                await MainActor.run {
                                    isLoading = false
                                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                                        errorMessage = "Failed to sign in with \(provider.rawValue). Please try again."
                                    } else {
                                        isLoading = false
                                    }
                                }
                                return
                            }

                            guard let callbackURL = callbackURL else {
                                await MainActor.run {
                                    isLoading = false
                                    errorMessage = "OAuth authentication failed"
                                }
                                return
                            }

                            // Handle the OAuth callback
                            print("🔗 OAuth callback received: \(callbackURL)")
                            DeepLinkManager.shared.handleURL(callbackURL)
                        }
                    }

                    // Set presentation context before starting
                    session.presentationContextProvider = contextProvider
                    session.prefersEphemeralWebBrowserSession = false
                    session.start()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ OAuth error: \(error)")
                    errorMessage = "Failed to sign in with \(provider.rawValue). Please try again."
                }
            }
        }
    }

    func saveTermsAcceptance(userId: UUID) async throws {
        struct TermsData: Encodable {
            let user_id: String
            let accepted_at: String
            let terms_version: String
        }

        let termsData = TermsData(
            user_id: userId.uuidString,
            accepted_at: ISO8601DateFormatter().string(from: Date()),
            terms_version: "1.0"
        )

        try await SupabaseManager.shared.client
            .from("terms_acceptance")
            .insert(termsData)
            .execute()

        print("✅ Terms acceptance saved")
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

                        // Request push notification permission
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                print("✅ Push notifications enabled")
                            } else {
                                print("⚠️ Push notifications declined")
                            }
                        }
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

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - ASWebAuthenticationSession Presentation Context Provider

class ASWebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the first active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

#Preview {
    AuthView()
}

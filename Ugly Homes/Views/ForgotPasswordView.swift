//
//  ForgotPasswordView.swift
//  Ugly Homes
//
//  Forgot Password / Reset Password View
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var showResetSuccess: Bool

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                // Same gradient background as auth page
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.65, blue: 0.3),
                        Color(red: 1.0, green: 0.45, blue: 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "lock.rotation")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 10)

                    // Title and description
                    VStack(spacing: 12) {
                        Text("Reset Password")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Email input
                    VStack(spacing: 16) {
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

                        // Send reset link button
                        Button(action: sendResetLink) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Send Reset Link")
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
                        .disabled(isLoading || email.isEmpty)
                        .opacity(email.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    func sendResetLink() {
        guard !email.isEmpty else { return }

        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }

        isLoading = true
        errorMessage = ""

        Task {
            do {
                // Send password reset email via Supabase with redirect URL
                try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
                    email,
                    redirectTo: URL(string: "housers://reset-password")
                )

                print("✅ Password reset email sent to: \(email)")

                await MainActor.run {
                    isLoading = false
                    dismiss()
                    showResetSuccess = true
                }
            } catch {
                print("❌ Error sending reset email: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to send reset email. Please try again."
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView(showResetSuccess: .constant(false))
}

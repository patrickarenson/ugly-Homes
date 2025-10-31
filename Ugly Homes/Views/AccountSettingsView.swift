//
//  AccountSettingsView.swift
//  Ugly Homes
//
//  Account Settings View - Change Email/Password
//

import SwiftUI
import Supabase

struct AccountSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @State private var currentEmail = ""
    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    @State private var showChangeEmail = false
    @State private var showChangePassword = false

    var body: some View {
        NavigationView {
            List {
                // Current email section
                Section {
                    HStack {
                        Text("Current Email")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(currentEmail)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Account Information")
                }

                // Change email section
                Section {
                    if showChangeEmail {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("New Email", text: $newEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()

                            SecureField("Current Password", text: $currentPassword)

                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    showChangeEmail = false
                                    newEmail = ""
                                    currentPassword = ""
                                }
                                .foregroundColor(.gray)

                                Spacer()

                                Button("Update Email") {
                                    updateEmail()
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .disabled(newEmail.isEmpty || currentPassword.isEmpty)
                            }
                        }
                    } else {
                        Button("Change Email") {
                            showChangeEmail = true
                        }
                        .foregroundColor(.orange)
                    }
                } header: {
                    Text("Email")
                }

                // Change password section
                Section {
                    if showChangePassword {
                        VStack(alignment: .leading, spacing: 12) {
                            SecureField("Current Password", text: $currentPassword)

                            SecureField("New Password", text: $newPassword)

                            SecureField("Confirm New Password", text: $confirmPassword)

                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    showChangePassword = false
                                    currentPassword = ""
                                    newPassword = ""
                                    confirmPassword = ""
                                }
                                .foregroundColor(.gray)

                                Spacer()

                                Button("Update Password") {
                                    updatePassword()
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                            }
                        }
                    } else {
                        Button("Change Password") {
                            showChangePassword = true
                        }
                        .foregroundColor(.orange)
                    }
                } header: {
                    Text("Password")
                }

                // Messages
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentEmail()
            }
        }
    }

    func loadCurrentEmail() {
        Task {
            do {
                let user = try await SupabaseManager.shared.client.auth.session.user
                currentEmail = user.email ?? ""
            } catch {
                print("❌ Error loading user: \(error)")
            }
        }
    }

    func updateEmail() {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        Task {
            do {
                // Validate email format
                guard newEmail.contains("@") && newEmail.contains(".") else {
                    errorMessage = "Please enter a valid email address"
                    isLoading = false
                    return
                }

                // Update email in Supabase Auth
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(email: newEmail)
                )

                successMessage = "✅ Email update requested! Check your inbox to confirm."
                showChangeEmail = false
                newEmail = ""
                currentPassword = ""
                isLoading = false

                // Reload email after update
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    loadCurrentEmail()
                }
            } catch {
                errorMessage = "Failed to update email: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    func updatePassword() {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        // Validate passwords match
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match"
            isLoading = false
            return
        }

        // Validate password length
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            return
        }

        Task {
            do {
                // Update password in Supabase Auth
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: newPassword)
                )

                successMessage = "✅ Password updated successfully!"
                showChangePassword = false
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                isLoading = false
            } catch {
                errorMessage = "Failed to update password: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    AccountSettingsView()
}

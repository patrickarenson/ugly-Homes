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
    @State private var showDeleteAlert = false
    @State private var deleteConfirmationText = ""
    @State private var isMigratingTags = false
    @State private var migrationMessage = ""
    @State private var isAdmin = false

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

                // Admin Tools section (only for housers and patrick)
                if isAdmin {
                    Section {
                        Button(action: {
                            migrateAllTags()
                        }) {
                            HStack {
                                if isMigratingTags {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Updating Tags...")
                                } else {
                                    Image(systemName: "tag.fill")
                                    Text("Regenerate All Property Tags")
                                }
                            }
                            .foregroundColor(.blue)
                        }
                        .disabled(isMigratingTags)

                        Button(action: {
                            migrateOpenHouseTags()
                        }) {
                            HStack {
                                if isMigratingTags {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Adding #OpenHouse Tags...")
                                } else {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("Add #OpenHouse Tags to Existing Posts")
                                }
                            }
                            .foregroundColor(.orange)
                        }
                        .disabled(isMigratingTags)

                        if !migrationMessage.isEmpty {
                            Text(migrationMessage)
                                .font(.caption)
                                .foregroundColor(migrationMessage.contains("✅") ? .green : .red)
                        }
                    } header: {
                        Text("Admin Tools")
                    } footer: {
                        Text("Regenerate tags for all properties or add #OpenHouse tag to existing posts with open houses for searchability.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Delete account section
                Section {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Account")
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Permanently delete your account and all associated data. This action cannot be undone.")
                        .font(.caption)
                        .foregroundColor(.gray)
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
                checkAdminStatus()
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    .textInputAutocapitalization(.characters)

                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }

                Button("Delete", role: .destructive) {
                    if deleteConfirmationText == "DELETE" {
                        deleteAccount()
                    } else {
                        errorMessage = "Please type DELETE to confirm"
                    }
                    deleteConfirmationText = ""
                }
            } message: {
                Text("This will permanently delete your account and all your posts, likes, comments, and messages. This action cannot be undone.\n\nType DELETE to confirm.")
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

    func checkAdminStatus() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct ProfileUsername: Codable {
                    let username: String
                }

                let profile: ProfileUsername = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("username")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value

                // Only housers and patrick have admin access
                let adminUsernames = ["housers", "patrick"]
                await MainActor.run {
                    isAdmin = adminUsernames.contains(profile.username.lowercased())
                }
            } catch {
                print("❌ Error checking admin status: \(error)")
                await MainActor.run {
                    isAdmin = false
                }
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

    func deleteAccount() {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        Task {
            do {
                // Get current user
                let user = try await SupabaseManager.shared.client.auth.session.user
                print("🗑️ Deleting account for user: \(user.id)")

                // Delete user's profile (cascade will delete all related data)
                // The database has cascade delete rules for:
                // - homes (and their likes, comments, shares, saves, views)
                // - conversations and messages
                // - follows
                print("🗑️ Deleting profile and all associated data...")
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .delete()
                    .eq("id", value: user.id.uuidString)
                    .execute()

                print("✅ Profile and all data deleted from database")

                // Delete auth account (this must be done after database deletion)
                print("🗑️ Deleting auth account...")
                // Note: Supabase doesn't have a direct client-side delete user method
                // The profile deletion trigger or RPC function should handle this
                // For now, just sign out
                try await SupabaseManager.shared.client.auth.signOut()

                // Clear saved credentials
                UserDefaults.standard.removeObject(forKey: "savedEmail")
                UserDefaults.standard.removeObject(forKey: "savedPassword")
                UserDefaults.standard.set(false, forKey: "rememberMe")
                print("🗑️ Cleared saved credentials")

                print("✅ Account deletion completed")

                // Notify the app to return to auth screen
                await MainActor.run {
                    NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
                    dismiss()
                }

                isLoading = false
            } catch {
                print("❌ Error deleting account: \(error)")
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    func migrateAllTags() {
        isMigratingTags = true
        migrationMessage = ""

        Task {
            do {
                try await TagMigrationHelper.updateAllPropertyTags()
                await MainActor.run {
                    migrationMessage = "✅ Successfully updated all property tags!"
                    isMigratingTags = false
                }
            } catch {
                await MainActor.run {
                    migrationMessage = "❌ Error: \(error.localizedDescription)"
                    isMigratingTags = false
                }
            }
        }
    }

    func migrateOpenHouseTags() {
        isMigratingTags = true
        migrationMessage = ""

        Task {
            do {
                try await OpenHouseTagMigration.addOpenHouseTagsToExistingPosts()
                await MainActor.run {
                    migrationMessage = "✅ Successfully added #OpenHouse tags!"
                    isMigratingTags = false
                }
            } catch {
                await MainActor.run {
                    migrationMessage = "❌ Error: \(error.localizedDescription)"
                    isMigratingTags = false
                }
            }
        }
    }
}

#Preview {
    AccountSettingsView()
}

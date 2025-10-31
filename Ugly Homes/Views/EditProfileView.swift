//
//  EditProfileView.swift
//  Ugly Homes
//
//  Edit Profile View
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    let currentProfile: Profile

    @State private var username: String
    @State private var fullName: String
    @State private var bio: String
    @State private var market: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var isUploading = false
    @State private var errorMessage = ""

    init(profile: Profile) {
        self.currentProfile = profile
        _username = State(initialValue: profile.username)
        _fullName = State(initialValue: profile.fullName ?? "")
        _bio = State(initialValue: profile.bio ?? "")
        _market = State(initialValue: profile.market ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile photo picker
                    VStack(spacing: 12) {
                        Text("Profile Photo")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            ZStack {
                                if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let avatarUrl = currentProfile.avatarUrl, let url = URL(string: avatarUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        defaultProfileImage
                                    }
                                } else {
                                    defaultProfileImage
                                }

                                // Show loading indicator during upload
                                if isUploading && profileImageData != nil {
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                Text("Uploading...")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                        )
                                } else {
                                    // Edit icon overlay
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .foregroundColor(.white)
                                                .font(.title2)
                                        )
                                }
                            }
                        }
                        .onChange(of: selectedImage) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    profileImageData = data
                                }
                            }
                        }
                    }

                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 15, weight: .medium))
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Full name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.system(size: 15, weight: .medium))
                        TextField("Full Name", text: $fullName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Bio
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bio")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text("\(bio.count)/100")
                                .font(.caption)
                                .foregroundColor(bio.count > 100 ? .red : .gray)
                        }
                        TextEditor(text: $bio)
                            .frame(height: 80)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: bio) { oldValue, newValue in
                                if newValue.count > 100 {
                                    bio = String(newValue.prefix(100))
                                }
                            }
                    }

                    // Market (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Market/Location")
                                .font(.system(size: 15, weight: .medium))
                            Text("(Optional)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        TextField("e.g., Miami, FL", text: $market)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    // Save button
                    Button(action: saveProfile) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.orange)
                    .cornerRadius(10)
                    .disabled(isUploading)
                }
                .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    var defaultProfileImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
    }

    func saveProfile() {
        guard !username.isEmpty else {
            errorMessage = "Username is required"
            return
        }

        isUploading = true
        errorMessage = ""

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Check if username is already taken (if changed)
                if username != currentProfile.username {
                    let existingProfiles: [Profile] = try await SupabaseManager.shared.client
                        .from("profiles")
                        .select()
                        .eq("username", value: username)
                        .execute()
                        .value

                    if !existingProfiles.isEmpty {
                        errorMessage = "Username '\(username)' is already taken"
                        isUploading = false
                        return
                    }
                }

                var avatarUrl: String?

                // Upload profile image if selected (skip if fails)
                if let imageData = profileImageData {
                    let fileName = "\(userId.uuidString)-profile.jpg"

                    // Try to upload, but continue even if it fails
                    do {
                        try await SupabaseManager.shared.client.storage
                            .from("profile-images")
                            .upload(
                                fileName,
                                data: imageData,
                                options: .init(
                                    cacheControl: "3600",
                                    contentType: "image/jpeg",
                                    upsert: true
                                )
                            )

                        let publicURL = try SupabaseManager.shared.client.storage
                            .from("profile-images")
                            .getPublicURL(path: fileName)

                        avatarUrl = publicURL.absoluteString
                    } catch let uploadError {
                        errorMessage = "Photo upload failed: \(uploadError.localizedDescription)"
                        // Don't stop - just skip the avatar update
                    }
                }

                // Update profile in database
                struct ProfileUpdate: Encodable {
                    let username: String
                    let full_name: String?
                    let bio: String?
                    let market: String?
                    let avatar_url: String?
                }

                let finalAvatarUrl = avatarUrl ?? currentProfile.avatarUrl

                let update = ProfileUpdate(
                    username: username,
                    full_name: fullName.isEmpty ? nil : fullName,
                    bio: bio.isEmpty ? nil : bio,
                    market: market.isEmpty ? nil : market,
                    avatar_url: finalAvatarUrl
                )

                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(update)
                    .eq("id", value: userId.uuidString)
                    .execute()

                isUploading = false

                // Notify to refresh
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)

                // Wait a moment for the notification to be processed
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                dismiss()
            } catch {
                print("❌ Error updating profile: \(error)")
                if let errorDescription = error as? LocalizedError {
                    errorMessage = errorDescription.errorDescription ?? "Failed to update profile"
                } else {
                    errorMessage = "Failed to update profile. Please try again."
                }
                isUploading = false
            }
        }
    }
}

#Preview {
    EditProfileView(profile: Profile(
        id: UUID(),
        username: "testuser",
        fullName: "Test User",
        avatarUrl: nil,
        bio: "This is my bio",
        createdAt: Date(),
        updatedAt: Date()
    ))
}

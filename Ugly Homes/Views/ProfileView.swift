//
//  ProfileView.swift
//  Ugly Homes
//
//  User Profile View
//

import SwiftUI

struct ProfileView: View {
    @State private var profile: Profile?
    @State private var userHomes: [Home] = []
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showAccountSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let profile = profile {
                        // Profile header
                        VStack(spacing: 12) {
                            // Profile photo
                            if let avatarUrl = profile.avatarUrl, !avatarUrl.isEmpty, let baseUrl = URL(string: avatarUrl) {
                                // Add timestamp to force image reload
                                let urlWithTimestamp = URL(string: "\(avatarUrl)?t=\(Date().timeIntervalSince1970)")
                                AsyncImage(url: urlWithTimestamp ?? baseUrl) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(.white)
                                        )
                                }
                                .id(avatarUrl) // Force SwiftUI to recreate the view when URL changes
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.white)
                                    )
                            }

                            Text(profile.username)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let bio = profile.bio {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 20)

                        // Stats
                        HStack(spacing: 0) {
                            VStack(spacing: 4) {
                                Text("\(userHomes.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Posts")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 4) {
                                Text("\(userHomes.reduce(0) { $0 + $1.likesCount })")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Likes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 4) {
                                Text("\(userHomes.reduce(0) { $0 + $1.commentsCount })")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Comments")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)

                        Divider()

                        // User's posts grid
                        if userHomes.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "house")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No posts yet")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 60)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 2) {
                                ForEach(userHomes) { home in
                                    if let imageUrl = home.imageUrls.first {
                                        AsyncImage(url: URL(string: imageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(1, contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .aspectRatio(1, contentMode: .fill)
                                        }
                                        .clipped()
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showEditProfile = true
                        }) {
                            Label("Edit Profile", systemImage: "pencil")
                        }

                        Button(action: {
                            showAccountSettings = true
                        }) {
                            Label("Account Settings", systemImage: "gearshape")
                        }

                        Button(role: .destructive, action: {
                            signOut()
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = profile {
                    EditProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showAccountSettings) {
                AccountSettingsView()
            }
            .onAppear {
                loadProfile()

                // Listen for profile refresh notifications
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("RefreshProfile"),
                    object: nil,
                    queue: .main
                ) { _ in
                    loadProfile()
                }
            }
        }
    }

    func loadProfile() {
        isLoading = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("📥 Loading profile for user: \(userId)")

                // Load profile
                let profileResponse: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value

                if let userProfile = profileResponse.first {
                    profile = userProfile
                }

                // Load user's homes
                let homesResponse: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("user_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                userHomes = homesResponse
                print("✅ Loaded profile with \(userHomes.count) posts")

                isLoading = false
            } catch {
                print("❌ Error loading profile: \(error)")
                isLoading = false
            }
        }
    }

    func signOut() {
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()
            NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
        }
    }
}

#Preview {
    ProfileView()
}

//
//  ProfileView.swift
//  Ugly Homes
//
//  User Profile View
//

import SwiftUI

struct ProfileView: View {
    let viewingUserId: UUID? // If nil, show own profile; if set, show this user's profile

    @State private var profile: Profile?
    @State private var userHomes: [Home] = []
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showAccountSettings = false
    @State private var selectedHome: Home?
    @State private var showPostDetail = false
    @State private var currentUserId: UUID?
    @State private var showChat = false

    init(viewingUserId: UUID? = nil) {
        self.viewingUserId = viewingUserId
    }

    var isViewingOtherProfile: Bool {
        guard let viewingId = viewingUserId, let currentId = currentUserId else {
            return false
        }
        return viewingId != currentId
    }

    var body: some View {
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

                            Text("@\(profile.username)")
                                .font(.system(size: 18))
                                .fontWeight(.semibold)

                            if let market = profile.market, !market.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(market)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }

                            if let bio = profile.bio {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.primary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            // Message button (only show when viewing another user's profile)
                            if isViewingOtherProfile {
                                Button(action: {
                                    showChat = true
                                }) {
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Message")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal, 40)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 20)

                        // Stats - Modern, compact single row
                        HStack(spacing: 0) {
                            VStack(spacing: 3) {
                                Text("\(userHomes.count)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Posts")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 3) {
                                Text("\(userHomes.filter { $0.soldStatus == "sold" }.count)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Sold")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 3) {
                                Text("\(userHomes.filter { $0.soldStatus == "leased" }.count)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Leased")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 3) {
                                let ranking = calculateRanking(homes: userHomes)
                                Text(ranking.text)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(ranking.color)
                                Text("Rank")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

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
                                        ZStack(alignment: .topTrailing) {
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

                                            // Sold/Leased badge overlay
                                            if let soldStatus = home.soldStatus {
                                                Text(soldStatus.uppercased())
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(soldStatus == "sold" ? Color.red : Color.blue)
                                                    .cornerRadius(4)
                                                    .padding(4)
                                            }
                                        }
                                        .onTapGesture {
                                            selectedHome = home
                                            showPostDetail = true
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Loading profile...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 100)
                }
            }
            .navigationTitle(isViewingOtherProfile ? (profile?.username ?? "Profile") : "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only show menu when viewing own profile
            if !isViewingOtherProfile {
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
        }
            .sheet(isPresented: $showEditProfile) {
                if let profile = profile {
                    EditProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showAccountSettings) {
                AccountSettingsView()
            }
            .sheet(isPresented: $showPostDetail) {
                if let home = selectedHome {
                    NavigationView {
                        ScrollView {
                            HomePostView(home: home, showSoldOptions: !isViewingOtherProfile, preloadedUserId: currentUserId)
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    showPostDetail = false
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showChat) {
                if let profile = profile {
                    ChatView(
                        otherUserId: profile.id,
                        otherUsername: profile.username,
                        otherAvatarUrl: profile.avatarUrl
                    )
                }
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

    func loadProfile() {
        isLoading = true

        Task {
            do {
                // Get current user ID
                let currentId = try await SupabaseManager.shared.client.auth.session.user.id
                currentUserId = currentId

                // Determine which user's profile to load
                let targetUserId = viewingUserId ?? currentId
                print("📥 Loading profile for user: \(targetUserId)")

                // Load profile
                let profileResponse: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: targetUserId.uuidString)
                    .execute()
                    .value

                if let userProfile = profileResponse.first {
                    profile = userProfile
                }

                // Load user's homes
                let homesResponse: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("user_id", value: targetUserId.uuidString)
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

    func calculateRanking(homes: [Home]) -> (text: String, color: Color) {
        // Get current year
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // Count only deals closed THIS YEAR (keeps competition fresh annually)
        let dealsThisYear = homes.filter { home in
            guard let soldDate = home.soldDate else { return false }
            let dealYear = calendar.component(.year, from: soldDate)
            return dealYear == currentYear && home.soldStatus != nil
        }.count

        // Competitive ranking algorithm with color coding
        // Resets every year to keep agents grinding!
        if dealsThisYear >= 10 {
            return ("5%", Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
        } else if dealsThisYear >= 7 {
            return ("10%", Color.green)
        } else if dealsThisYear >= 5 {
            return ("15%", Color.blue)
        } else if dealsThisYear >= 3 {
            return ("25%", Color.purple)
        } else if dealsThisYear >= 1 {
            return ("50%", Color.orange)
        } else {
            return ("75%", Color.gray)
        }

        // Future enhancement: Compare against actual users in same market
        // Can query database for market-based competitive rankings
    }
}


#Preview {
    ProfileView()
}

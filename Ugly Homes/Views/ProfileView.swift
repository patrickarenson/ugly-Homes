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
    @State private var bookmarkedHomes: [Home] = []
    @State private var showingBookmarks = false
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showAccountSettings = false
    @State private var currentUserId: UUID?
    @State private var showChat = false
    @State private var showBlockAlert = false
    @State private var showBlockConfirmation = false
    @State private var showShareSheet = false
    @State private var isFollowing = false

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
                        // Profile photo with initial fallback
                        AvatarView(
                            avatarUrl: profile.avatarUrl,
                            username: profile.username,
                            size: 80
                        )

                        HStack(spacing: 6) {
                            Text("@\(profile.username)")
                                .font(.system(size: 18))
                                .fontWeight(.semibold)

                            if profile.isVerified == true {
                                VerifiedBadge()
                            }
                        }

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

                        if let bio = profile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Show "Complete Your Profile" button if viewing own profile and missing bio/location
                        if !isViewingOtherProfile {
                            let hasBio = profile.bio != nil && !profile.bio!.isEmpty
                            let hasLocation = profile.market != nil && !profile.market!.isEmpty

                            if !hasBio || !hasLocation {
                                Button(action: {
                                    showEditProfile = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.subheadline)
                                        Text("Complete Your Profile")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                                }
                                .padding(.top, 4)
                            }
                        }

                        // Follow/Unfollow button
                        if isViewingOtherProfile {
                            Button(action: {
                                toggleFollow()
                            }) {
                                HStack {
                                    Image(systemName: isFollowing ? "person.fill.checkmark" : "person.fill.badge.plus")
                                    Text(isFollowing ? "Following" : "Follow")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(isFollowing ? .gray : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isFollowing ? Color.gray.opacity(0.2) : Color.orange)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top)

                    // Stats - Modern, compact single row
                    profileStatsView
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    Divider()

                    // Grid - Shows either user's posts or bookmarked homes
                    if showingBookmarks {
                        // Bookmarked homes grid
                        if bookmarkedHomes.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No saved homes yet")
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
                                ForEach(bookmarkedHomes) { home in
                                    if let imageUrl = home.imageUrls.first {
                                        NavigationLink(destination: PostDetailView(home: home, showSoldOptions: false, preloadedUserId: currentUserId)) {
                                            ZStack(alignment: .topTrailing) {
                                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.2))
                                                            .aspectRatio(1, contentMode: .fill)
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .aspectRatio(1, contentMode: .fill)
                                                    case .failure:
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.2))
                                                            .aspectRatio(1, contentMode: .fill)
                                                    @unknown default:
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.2))
                                                            .aspectRatio(1, contentMode: .fill)
                                                    }
                                                }
                                                .clipped()

                                                VStack(alignment: .trailing, spacing: 4) {
                                                    // Manual status badge
                                                    if let soldStatus = home.soldStatus {
                                                        Text(soldStatus.uppercased())
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 3)
                                                            .background(
                                                                soldStatus == "sold" ? Color.red :
                                                                soldStatus == "leased" ? Color.blue :
                                                                soldStatus == "pending" ? Color.yellow : Color.gray
                                                            )
                                                            .cornerRadius(4)
                                                    }

                                                    // Automatic listing status badge from Zillow API
                                                    if let listingStatus = home.listingStatus, listingStatus != "active" {
                                                        Text(listingStatus.uppercased())
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 3)
                                                            .background(
                                                                listingStatus == "sold" ? Color.green :
                                                                listingStatus == "pending" ? Color.orange :
                                                                listingStatus == "off_market" ? Color.red : Color.gray
                                                            )
                                                            .cornerRadius(4)
                                                    }

                                                    // Price Drop/Increase badge (automatic from price tracking)
                                                    if let priceHistory = home.priceHistory, !priceHistory.isEmpty,
                                                       let latestChange = priceHistory.last {
                                                        let isDecrease = latestChange.change < 0
                                                        let changePercent = abs(Double(truncating: latestChange.changePercent as NSNumber))

                                                        HStack(spacing: 2) {
                                                            Image(systemName: isDecrease ? "arrow.down" : "arrow.up")
                                                                .font(.system(size: 7, weight: .bold))
                                                            Text("\(Int(changePercent))%")
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(isDecrease ? Color.blue : Color.red)
                                                        .cornerRadius(4)
                                                    }

                                                    if home.openHousePaid == true, let openHouseDate = home.openHouseDate {
                                                        let isUpcoming = openHouseDate > Date().addingTimeInterval(-86400)
                                                        if isUpcoming {
                                                            Text("OPEN HOUSE")
                                                                .font(.system(size: 8, weight: .bold))
                                                                .foregroundColor(.white)
                                                                .padding(.horizontal, 5)
                                                                .padding(.vertical, 2)
                                                                .background(Color.green)
                                                                .cornerRadius(4)
                                                        }
                                                    }
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // User's posts grid
                        if userHomes.isEmpty && !isLoading {
                            VStack(spacing: 24) {
                                // Welcome icon
                                Image(systemName: "hand.wave.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))

                                // Welcome message
                                VStack(spacing: 8) {
                                    Text("Welcome to Houser!")
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text("Your profile is ready - now it's time to share properties you love")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }

                                // Feature bullets
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "link.circle.fill")
                                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                                        Text("Import listings from Zillow")
                                            .font(.subheadline)
                                    }

                                    HStack(spacing: 12) {
                                        Image(systemName: "house.circle.fill")
                                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                                        Text("Share homes you're watching")
                                            .font(.subheadline)
                                    }

                                    HStack(spacing: 12) {
                                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                                        Text("Share your home renovation projects")
                                            .font(.subheadline)
                                    }
                                }
                                .padding(.horizontal, 40)

                                // CTA Button
                                NavigationLink(destination: CreatePostView()) {
                                    Text("Add Your First Property")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 1.0, green: 0.65, blue: 0.3),
                                                    Color(red: 1.0, green: 0.45, blue: 0.2)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.3).opacity(0.3), radius: 10, x: 0, y: 5)
                                }
                                .padding(.horizontal, 40)
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 2) {
                                ForEach(userHomes) { home in
                                if let imageUrl = home.imageUrls.first {
                                    NavigationLink(destination: PostDetailView(home: home, showSoldOptions: !isViewingOtherProfile, preloadedUserId: currentUserId)) {
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                                switch phase {
                                                case .empty:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .aspectRatio(1, contentMode: .fill)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(1, contentMode: .fill)
                                                case .failure:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .aspectRatio(1, contentMode: .fill)
                                                @unknown default:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .aspectRatio(1, contentMode: .fill)
                                                }
                                            }
                                            .clipped()

                                            VStack(alignment: .trailing, spacing: 4) {
                                                // Sold/Leased/Pending badge overlay (manual)
                                                if let soldStatus = home.soldStatus {
                                                    Text(soldStatus.uppercased())
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(
                                                            soldStatus == "sold" ? Color.red :
                                                            soldStatus == "leased" ? Color.blue :
                                                            soldStatus == "pending" ? Color.yellow : Color.gray
                                                        )
                                                        .cornerRadius(4)
                                                }

                                                // Automatic listing status badge from Zillow API
                                                if let listingStatus = home.listingStatus, listingStatus != "active" {
                                                    Text(listingStatus.uppercased())
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(
                                                            listingStatus == "sold" ? Color.green :
                                                            listingStatus == "pending" ? Color.orange :
                                                            listingStatus == "off_market" ? Color.red : Color.gray
                                                        )
                                                        .cornerRadius(4)
                                                }

                                                // Price Drop/Increase badge (automatic from price tracking)
                                                if let priceHistory = home.priceHistory, !priceHistory.isEmpty,
                                                   let latestChange = priceHistory.last {
                                                    let isDecrease = latestChange.change < 0
                                                    let changePercent = abs(Double(truncating: latestChange.changePercent as NSNumber))

                                                    HStack(spacing: 2) {
                                                        Image(systemName: isDecrease ? "arrow.down" : "arrow.up")
                                                            .font(.system(size: 7, weight: .bold))
                                                        Text("\(Int(changePercent))%")
                                                            .font(.system(size: 9, weight: .bold))
                                                    }
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(isDecrease ? Color.blue : Color.red)
                                                    .cornerRadius(4)
                                                }

                                                // Open House badge
                                                if home.openHousePaid == true, let openHouseDate = home.openHouseDate {
                                                    // Only show if open house is in the future or within the last 24 hours
                                                    let isUpcoming = openHouseDate > Date().addingTimeInterval(-86400)
                                                    if isUpcoming {
                                                        Text("OPEN HOUSE")
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 2)
                                                            .background(Color.green)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                            .padding(4)
                                        }
                                    }
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
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .navigationTitle(isViewingOtherProfile ? (profile?.username ?? "Profile") : "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Combined toolbar items for proper alignment
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(alignment: .top, spacing: 16) {
                    // Share button (always shown)
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }

                    // Show menu when viewing own profile
                    if !isViewingOtherProfile {
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
                                .foregroundColor(.orange)
                        }
                    }

                    // Show menu when viewing another user's profile
                    if isViewingOtherProfile {
                        Menu {
                            Button(role: .destructive, action: {
                                showBlockAlert = true
                            }) {
                                Label("Block User", systemImage: "hand.raised.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
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
        .sheet(isPresented: $showChat) {
            if let profile = profile {
                let _ = print("🟢 Sheet presenting in ProfileView for: \(profile.username)")
                NavigationView {
                    ChatView(
                        otherUserId: profile.id,
                        otherUsername: profile.username,
                        otherAvatarUrl: profile.avatarUrl
                    )
                }
            } else {
                let _ = print("🔴 profile is nil in sheet!")
                Text("Error loading profile")
            }
        }
        .alert("Block User", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block @\(profile?.username ?? "this user")? You won't see their posts anymore.")
        }
        .alert("User Blocked", isPresented: $showBlockConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have successfully blocked this user. You won't see their posts anymore.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let profile = profile {
                ActivityViewController(items: [generateProfileURL(username: profile.username)])
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

    // Helper view to fix compiler type-checking timeout
    var profileStatsView: some View {
        HStack(spacing: 0) {
            statItem(count: userHomes.count, label: "Posts")
            statItem(count: profile?.followersCount ?? 0, label: "Followers")
            statItem(count: profile?.followingCount ?? 0, label: "Following")

            // Bookmark toggle button
            Button(action: {
                showingBookmarks.toggle()
                if showingBookmarks {
                    loadBookmarks()
                }
            }) {
                VStack(spacing: 3) {
                    Image(systemName: showingBookmarks ? "square.grid.3x3.fill" : "bookmark.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(showingBookmarks ? "Posts" : "Saved")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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

                // Update UI with profile data
                await MainActor.run {
                    if let userProfile = profileResponse.first {
                        profile = userProfile
                    }
                    // Keep loading state until homes are loaded too
                }

                // Load user's homes in background (need to include profile for HomePostView)
                let homesResponse: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("user_id", value: targetUserId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                await MainActor.run {
                    userHomes = homesResponse
                    isLoading = false // Only set to false after both profile AND homes are loaded
                    print("✅ Loaded profile with \(userHomes.count) posts")
                }

                // Check follow status if viewing another user's profile
                if isViewingOtherProfile {
                    checkFollowStatus()
                }
            } catch {
                print("❌ Error loading profile: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    func signOut() {
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()

            // Clear saved credentials
            UserDefaults.standard.removeObject(forKey: "savedEmail")
            UserDefaults.standard.removeObject(forKey: "savedPassword")
            UserDefaults.standard.set(false, forKey: "rememberMe")
            print("🗑️ Cleared saved credentials on sign out")

            NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)
        }
    }

    func blockUser() {
        guard let profile = profile, let currentUserId = currentUserId else {
            print("❌ Cannot block - missing profile or current user ID")
            return
        }

        Task {
            do {
                print("🚫 Blocking user: @\(profile.username)")

                struct BlockData: Encodable {
                    let blocker_id: String
                    let blocked_id: String
                }

                let block = BlockData(
                    blocker_id: currentUserId.uuidString,
                    blocked_id: profile.id.uuidString
                )

                try await SupabaseManager.shared.client
                    .from("blocked_users")
                    .insert(block)
                    .execute()

                print("✅ User blocked successfully")

                // Show confirmation message
                await MainActor.run {
                    showBlockConfirmation = true
                }

                // Post notification to refresh feed (remove blocked user's posts)
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
            } catch {
                print("❌ Error blocking user: \(error)")
            }
        }
    }

    func toggleFollow() {
        guard let profile = profile, let currentUserId = currentUserId else {
            print("❌ Cannot toggle follow - missing profile or current user ID")
            return
        }

        Task {
            do {
                if isFollowing {
                    // Unfollow
                    print("🔄 Unfollowing @\(profile.username)")
                    try await SupabaseManager.shared.client
                        .from("follows")
                        .delete()
                        .eq("follower_id", value: currentUserId.uuidString)
                        .eq("following_id", value: profile.id.uuidString)
                        .execute()
                    print("✅ Unfollowed @\(profile.username)")
                } else {
                    // Follow
                    print("🔄 Following @\(profile.username)")
                    struct FollowData: Encodable {
                        let follower_id: String
                        let following_id: String
                    }

                    try await SupabaseManager.shared.client
                        .from("follows")
                        .insert(FollowData(
                            follower_id: currentUserId.uuidString,
                            following_id: profile.id.uuidString
                        ))
                        .execute()
                    print("✅ Followed @\(profile.username)")
                }

                await MainActor.run {
                    isFollowing.toggle()
                }

                // Refresh profile to update follower counts
                loadProfile()
            } catch {
                print("❌ Error toggling follow: \(error)")
            }
        }
    }

    func checkFollowStatus() {
        guard let profile = profile, let currentUserId = currentUserId else { return }

        Task {
            do {
                struct Follow: Decodable {
                    let id: UUID
                }

                let response: [Follow] = try await SupabaseManager.shared.client
                    .from("follows")
                    .select()
                    .eq("follower_id", value: currentUserId.uuidString)
                    .eq("following_id", value: profile.id.uuidString)
                    .execute()
                    .value

                await MainActor.run {
                    isFollowing = !response.isEmpty
                    print("🔍 Follow status for @\(profile.username): \(isFollowing ? "Following" : "Not following")")
                }
            } catch {
                print("❌ Error checking follow status: \(error)")
            }
        }
    }

    func loadBookmarks() {
        Task {
            do {
                guard let userId = currentUserId else {
                    print("❌ No current user ID to load bookmarks")
                    return
                }

                print("🔍 Loading bookmarks for user: \(userId)")

                // First, get all bookmark IDs for this user
                struct BookmarkRecord: Decodable {
                    let home_id: UUID
                }

                let bookmarkRecords: [BookmarkRecord] = try await SupabaseManager.shared.client
                    .from("bookmarks")
                    .select("home_id")
                    .eq("user_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                print("📋 Found \(bookmarkRecords.count) bookmark records")

                if bookmarkRecords.isEmpty {
                    await MainActor.run {
                        bookmarkedHomes = []
                    }
                    return
                }

                // Now fetch the actual homes
                let homeIds = bookmarkRecords.map { $0.home_id.uuidString }

                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .in("id", values: homeIds)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) bookmarked homes")

                await MainActor.run {
                    // Sort homes to match bookmark order
                    bookmarkedHomes = homeIds.compactMap { homeIdString in
                        response.first { $0.id.uuidString == homeIdString }
                    }
                }
            } catch {
                print("❌ Error loading bookmarks: \(error)")
            }
        }
    }

    func calculateRanking(homes: [Home]) -> (text: String, color: Color) {
        // Get current year
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // Count only deals closed THIS YEAR (keeps competition fresh annually)
        // Exclude "pending" status - only count "sold" and "leased"
        let dealsThisYear = homes.filter { home in
            guard let soldDate = home.soldDate else { return false }
            let dealYear = calendar.component(.year, from: soldDate)
            return dealYear == currentYear && (home.soldStatus == "sold" || home.soldStatus == "leased")
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

    /// Generate shareable profile URL
    func generateProfileURL(username: String) -> URL {
        // Use universal link format for better compatibility
        return URL(string: "https://housers.us/@\(username)")!
    }
}

/// Native iOS Activity View Controller for sharing
struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}


// Post Detail View - wraps HomePostView for NavigationLink
struct PostDetailView: View {
    let home: Home
    let showSoldOptions: Bool
    let preloadedUserId: UUID?
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            HomePostView(home: home, searchText: $searchText, showSoldOptions: showSoldOptions, preloadedUserId: preloadedUserId)
                .id("\(home.id)-\(home.soldStatus ?? "none")-\(home.updatedAt.timeIntervalSince1970)")
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText) { oldValue, newValue in
            // If user taps a tag, post notification to switch to feed tab and search
            if !newValue.isEmpty && oldValue.isEmpty {
                print("🏷️ Tag tapped: \(newValue), navigating to feed")
                // Post notification to switch to feed tab and search
                NotificationCenter.default.post(
                    name: NSNotification.Name("SearchByTag"),
                    object: nil,
                    userInfo: ["tag": newValue]
                )
                // Clear searchText so it can be used again
                searchText = ""
            }
        }
    }
}

#Preview {
    ProfileView()
}

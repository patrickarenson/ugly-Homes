//
//  FeedView.swift
//  Ugly Homes
//
//  Home Feed View
//

import SwiftUI

struct FeedView: View {
    @State private var homes: [Home] = []
    @State private var allHomes: [Home] = []
    @State private var isLoading = true
    @State private var showCreatePost = false
    @State private var searchText = ""
    @State private var searchResults: [Home] = []
    @State private var showNotifications = false
    @State private var unreadNotificationsCount = 0
    @State private var newlyCreatedPostIds: Set<UUID> = [] // Track posts created this session

    var filteredHomes: [Home] {
        if searchText.isEmpty {
            return homes
        } else {
            // When searching, use searchResults if available, otherwise fall back to allHomes
            let searchSource = searchResults.isEmpty ? allHomes : searchResults

            let filtered = searchSource.filter { home in
                let search = searchText.lowercased()
                // Normalize search: remove # and spaces for flexible matching
                let normalizedSearch = search.replacingOccurrences(of: "#", with: "").replacingOccurrences(of: " ", with: "")

                // Search by tags (hashtags)
                if let tags = home.tags {
                    print("🔍 Checking home '\(home.title)' with tags: \(tags)")
                    for tag in tags {
                        let normalizedTag = tag.lowercased().replacingOccurrences(of: "#", with: "").replacingOccurrences(of: " ", with: "")
                        // Match if normalized tag contains normalized search
                        // This makes "open house", "#openhouse", "OpenHouse" all match #OpenHouse
                        if normalizedTag.contains(normalizedSearch) || tag.lowercased().contains(search) {
                            print("✅ MATCH FOUND: '\(tag)' matches search '\(search)'")
                            return true
                        }
                    }
                }

                // Search by username
                if let username = home.profile?.username, username.lowercased().contains(search) {
                    return true
                }

                // Search by address, city, state, zip
                if let address = home.address, address.lowercased().contains(search) {
                    return true
                }
                if let city = home.city, city.lowercased().contains(search) {
                    return true
                }
                if let state = home.state, state.lowercased().contains(search) {
                    return true
                }
                if let zipCode = home.zipCode, zipCode.contains(searchText) {
                    return true
                }
                return false
            }

            return filtered
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))

                        TextField("Search by tag, username, or address", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                            .onChange(of: searchText) { oldValue, newValue in
                                if !newValue.isEmpty && newValue.count >= 2 {
                                    performDatabaseSearch(query: newValue)
                                } else {
                                    searchResults = []
                                }
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Notifications button
                    Button(action: {
                        showNotifications = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)

                            // Badge showing unread count
                            if unreadNotificationsCount > 0 {
                                Text("\(unreadNotificationsCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }

                    Button(action: {
                        showCreatePost = true
                    }) {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

                Divider()

                // Content
                if isLoading {
                    // Loading skeleton (Instagram-style)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { _ in
                                LoadingSkeletonView()
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                } else if filteredHomes.isEmpty {
                    VStack(spacing: 16) {
                        if searchText.isEmpty {
                            // Housers logo for empty state
                            if let logo = UIImage(named: "HousersLogo") {
                                Image(uiImage: logo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                            } else {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                            }

                            Text("Be the first to post your newest real estate project or listing")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No results found")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Try searching for a different property")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !filteredHomes.isEmpty {
                                ForEach(filteredHomes) { home in
                                    HomePostView(home: home, searchText: $searchText)
                                        .id("\(home.id)-\(home.soldStatus ?? "none")-\(home.updatedAt.timeIntervalSince1970)-\(home.tags?.joined(separator: ",") ?? "")")
                                        .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                hideKeyboard()
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .onChange(of: showCreatePost) { oldValue, newValue in
                if !newValue {
                    // Refresh feed when create post sheet is dismissed
                    loadHomes()
                }
            }
            .onChange(of: showNotifications) { oldValue, newValue in
                if !newValue {
                    // Refresh unread count when notifications sheet is dismissed
                    loadUnreadNotificationsCount()
                }
            }
            .onAppear {
                print("🎬 FeedView appeared - loading homes...")
                loadHomes()
                loadUnreadNotificationsCount()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewPostCreated"))) { notification in
                print("📢 RECEIVED NewPostCreated notification!")
                // Track the newly created post ID
                if let postId = notification.userInfo?["postId"] as? UUID {
                    print("🆕 Adding post ID to session tracking: \(postId)")
                    newlyCreatedPostIds.insert(postId)
                }
                print("🔄 New post created, reloading feed...")
                loadHomes()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshFeed"))) { _ in
                loadHomes()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshProfile"))) { _ in
                loadHomes() // Reload to get updated profile photos
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshNotifications"))) { _ in
                loadUnreadNotificationsCount()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("SetSearchText"))) { notification in
                if let tag = notification.userInfo?["searchText"] as? String {
                    print("🔍 Setting search text from notification: \(tag)")
                    searchText = tag
                }
            }
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func performDatabaseSearch(query: String) {
        Task {
            do {
                print("🔍 Performing database search for: \(query)")

                // Search all posts in database (including current user's posts)
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .limit(50)
                    .execute()
                    .value

                print("✅ Database search returned \(response.count) total post results")

                // Debug: Print tags from first few results
                for (index, home) in response.prefix(5).enumerated() {
                    print("🏠 Property \(index + 1): \(home.title)")
                    print("   Tags: \(home.tags ?? [])")
                }

                await MainActor.run {
                    searchResults = response
                }
            } catch {
                print("❌ Error performing database search: \(error)")
                await MainActor.run {
                    searchResults = []
                }
            }
        }
    }

    func loadHomes() {
        print("🔄 loadHomes() called")
        isLoading = true

        Task {
            do {
                print("📥 Loading trending homes with algorithm...")

                // Get current user ID
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("👤 Current user ID: \(userId)")
                print("👤 Current user ID string: \(userId.uuidString)")

                // Call the get_trending_homes RPC function
                struct TrendingHomeResponse: Codable {
                    let id: UUID
                    let userId: UUID
                    let title: String
                    let listingType: String?
                    let description: String?
                    let price: Decimal?
                    let address: String?
                    let city: String?
                    let state: String?
                    let zipCode: String?
                    let bedrooms: Int?
                    let bathrooms: Decimal?
                    let imageUrls: [String]
                    let likesCount: Int
                    let commentsCount: Int
                    let isActive: Bool
                    let isArchived: Bool?
                    let archivedAt: Date?
                    let soldStatus: String?
                    let soldDate: Date?
                    let openHouseDate: Date?
                    let openHouseEndDate: Date?
                    let openHousePaid: Bool?
                    let subscriptionId: String?
                    let expiresAt: Date?
                    let tags: [String]?
                    let createdAt: Date
                    let updatedAt: Date
                    let trendingScore: Decimal

                    enum CodingKeys: String, CodingKey {
                        case id
                        case userId = "user_id"
                        case title
                        case listingType = "listing_type"
                        case description
                        case price
                        case address
                        case city
                        case state
                        case zipCode = "zip_code"
                        case bedrooms
                        case bathrooms
                        case imageUrls = "image_urls"
                        case likesCount = "likes_count"
                        case commentsCount = "comments_count"
                        case isActive = "is_active"
                        case isArchived = "is_archived"
                        case archivedAt = "archived_at"
                        case soldStatus = "sold_status"
                        case soldDate = "sold_date"
                        case openHouseDate = "open_house_date"
                        case openHouseEndDate = "open_house_end_date"
                        case openHousePaid = "open_house_paid"
                        case subscriptionId = "subscription_id"
                        case expiresAt = "expires_at"
                        case tags
                        case createdAt = "created_at"
                        case updatedAt = "updated_at"
                        case trendingScore = "trending_score"
                    }
                }

                let response: [TrendingHomeResponse] = try await SupabaseManager.shared.client
                    .rpc("get_trending_homes", params: ["requesting_user_id": userId])
                    .limit(30)  // Only load 30 homes initially for faster load
                    .execute()
                    .value

                print("✅ Loaded \(response.count) trending homes (limited for performance)")

                // OPTIMIZATION: Fetch all profiles in a single query instead of one-by-one
                struct ProfileResponse: Codable {
                    let id: UUID
                    let username: String
                    let fullName: String?
                    let avatarUrl: String?
                    let bio: String?
                    let isVerified: Bool?
                    let createdAt: Date
                    let updatedAt: Date

                    enum CodingKeys: String, CodingKey {
                        case id
                        case username
                        case fullName = "full_name"
                        case avatarUrl = "avatar_url"
                        case bio
                        case isVerified = "is_verified"
                        case createdAt = "created_at"
                        case updatedAt = "updated_at"
                    }
                }

                // Get unique user IDs
                let uniqueUserIds = Array(Set(response.map { $0.userId.uuidString }))
                print("📥 Fetching \(uniqueUserIds.count) unique profiles in one query...")

                // Fetch all profiles in a single query
                let profilesResponse: [ProfileResponse] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .in("id", values: uniqueUserIds)
                    .execute()
                    .value

                print("✅ Fetched \(profilesResponse.count) profiles")

                // Create a dictionary for fast profile lookup
                var profilesDict: [UUID: Profile] = [:]
                for p in profilesResponse {
                    profilesDict[p.id] = Profile(
                        id: p.id,
                        username: p.username,
                        fullName: p.fullName,
                        avatarUrl: p.avatarUrl,
                        bio: p.bio,
                        market: nil,
                        isVerified: p.isVerified,
                        createdAt: p.createdAt,
                        updatedAt: p.updatedAt
                    )
                }

                // Convert TrendingHomeResponse to Home with profiles
                var homesWithProfiles: [Home] = []
                for homeResponse in response {
                    var home = Home(
                        id: homeResponse.id,
                        userId: homeResponse.userId,
                        title: homeResponse.title,
                        listingType: homeResponse.listingType,
                        description: homeResponse.description,
                        price: homeResponse.price,
                        address: homeResponse.address,
                        city: homeResponse.city,
                        state: homeResponse.state,
                        zipCode: homeResponse.zipCode,
                        bedrooms: homeResponse.bedrooms,
                        bathrooms: homeResponse.bathrooms,
                        imageUrls: homeResponse.imageUrls,
                        likesCount: homeResponse.likesCount,
                        commentsCount: homeResponse.commentsCount,
                        viewCount: nil,
                        shareCount: nil,
                        saveCount: nil,
                        isActive: homeResponse.isActive,
                        isArchived: homeResponse.isArchived,
                        archivedAt: homeResponse.archivedAt,
                        soldStatus: homeResponse.soldStatus,
                        soldDate: homeResponse.soldDate,
                        openHouseDate: homeResponse.openHouseDate,
                        openHouseEndDate: homeResponse.openHouseEndDate,
                        openHousePaid: homeResponse.openHousePaid,
                        stripePaymentId: nil,
                        subscriptionId: homeResponse.subscriptionId,
                        expiresAt: homeResponse.expiresAt,
                        tags: homeResponse.tags,
                        createdAt: homeResponse.createdAt,
                        updatedAt: homeResponse.updatedAt
                    )
                    // Look up profile from dictionary (O(1) instead of network call)
                    home.profile = profilesDict[homeResponse.userId]
                    homesWithProfiles.append(home)
                }

                // Sort homes to put newly created posts first (this session only)
                let sortedHomes = homesWithProfiles.sorted { home1, home2 in
                    let isNew1 = newlyCreatedPostIds.contains(home1.id)
                    let isNew2 = newlyCreatedPostIds.contains(home2.id)

                    if isNew1 && !isNew2 {
                        return true // home1 is new, put it first
                    } else if !isNew1 && isNew2 {
                        return false // home2 is new, put it first
                    } else if isNew1 && isNew2 {
                        // Both are new - sort by creation date (newest first)
                        return home1.createdAt > home2.createdAt
                    } else {
                        // Neither are new - keep trending order
                        return false
                    }
                }

                homes = sortedHomes
                allHomes = sortedHomes

                // Debug: Print tags from first few homes
                print("🏷️ DEBUG - Tags from loaded homes:")
                for (index, home) in sortedHomes.prefix(3).enumerated() {
                    print("  Home \(index + 1): \(home.title)")
                    print("  Tags: \(home.tags ?? [])")
                    print("  Updated: \(home.updatedAt)")
                }

                // Print newly created posts (this session)
                if !newlyCreatedPostIds.isEmpty {
                    print("🆕 Session-created posts (will appear first):")
                    for id in newlyCreatedPostIds {
                        if let home = sortedHomes.first(where: { $0.id == id }) {
                            print("   - \(home.title)")
                        }
                    }
                }

                // DEBUG: Print sold status for all homes
                print("🔍 SOLD STATUS CHECK - Loaded \(sortedHomes.count) homes:")
                for home in sortedHomes.prefix(5) {
                    print("   📍 \(home.title): soldStatus='\(home.soldStatus ?? "nil")'")
                }

                // Print trending scores for debugging
                print("===== TRENDING SCORES =====")
                for (index, homeResponse) in response.prefix(5).enumerated() {
                    let isOwnPost = homeResponse.userId == userId
                    print("📊 #\(index + 1): \(homeResponse.title)")
                    print("   Score: \(homeResponse.trendingScore)")
                    print("   Own: \(isOwnPost ? "✅ YES" : "❌ NO")")
                    print("   Post UserID: \(homeResponse.userId)")
                }
                print("👤 Requesting User ID: \(userId)")
                print("==========================")

                isLoading = false
            } catch {
                print("❌ Error loading trending homes: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }

    func loadUnreadNotificationsCount() {
        Task {
            do {
                // Get current user ID
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Load only THIS user's unread notifications
                let response: [AppNotification] = try await SupabaseManager.shared.client
                    .from("notifications")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("is_read", value: false)
                    .execute()
                    .value

                await MainActor.run {
                    unreadNotificationsCount = response.count
                    print("🔔 Unread notifications for user \(userId): \(response.count)")
                }
            } catch {
                print("❌ Error loading unread notifications count: \(error)")
            }
        }
    }
}

struct HomePostView: View {
    let home: Home
    let showSoldOptions: Bool
    let preloadedUserId: UUID?
    @Binding var searchText: String
    @State private var showComments = false
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var currentPhotoIndex = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showMenu = false
    @State private var showDeleteAlert = false
    @State private var showHeartAnimation = false
    @State private var showEditPost = false
    @State private var showChat = false
    @State private var currentUserId: UUID?
    @State private var soldStatus: String?
    @State private var soldDate: Date?
    @State private var hasCheckedLike = false
    @State private var showShareSheet = false

    // User-generated pricing feature
    @State private var upVoted = false
    @State private var downVoted = false
    @State private var estimatedPrice: Int

    // Open house saved state
    @State private var isOpenHouseSaved = false
    @State private var showOpenHouseSavedMessage = false

    // Moderation features
    @State private var showReportDialog = false
    @State private var showBlockAlert = false
    @State private var showHideAlert = false
    @State private var showReportConfirmation = false
    @State private var showBlockConfirmation = false
    @State private var showHideConfirmation = false
    @State private var reportReason = ""

    init(home: Home, searchText: Binding<String>, showSoldOptions: Bool = true, preloadedUserId: UUID? = nil) {
        self.home = home
        self._searchText = searchText
        self.showSoldOptions = showSoldOptions
        self.preloadedUserId = preloadedUserId
        _likeCount = State(initialValue: home.likesCount)
        _estimatedPrice = State(initialValue: NSDecimalNumber(decimal: home.price ?? 0).intValue)
        _soldStatus = State(initialValue: home.soldStatus)
        _soldDate = State(initialValue: home.soldDate)
        _currentUserId = State(initialValue: preloadedUserId)

        // DEBUG: Log initialization
        print("🏗️ HomePostView INIT - \(home.title): soldStatus='\(home.soldStatus ?? "nil")', id=\(home.id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            HStack {
                NavigationLink(destination: {
                    if let profile = home.profile {
                        ProfileView(viewingUserId: profile.id)
                    }
                }) {
                    // Profile photo
                    if let avatarUrl = home.profile?.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                        // Add timestamp to prevent caching
                        let urlWithCache = URL(string: "\(avatarUrl)?t=\(Date().timeIntervalSince1970)")
                        AsyncImage(url: urlWithCache ?? url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    // Line 1: Username + badges
                    HStack(spacing: 8) {
                        NavigationLink(destination: ProfileView(viewingUserId: home.userId)) {
                            HStack(spacing: 4) {
                                Text("\(home.profile?.username ?? "user")")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                if home.profile?.isVerified == true {
                                    VerifiedBadge()
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // Sold/Leased/Pending badge
                        if let status = soldStatus {
                            Text(status.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    status == "sold" ? Color.red :
                                    status == "leased" ? Color.purple :
                                    status == "pending" ? Color.yellow : Color.gray
                                )
                                .cornerRadius(4)
                        }

                        // Open House badge (green) - only show if date hasn't passed
                        if let openHouseDate = home.openHouseDate, home.openHousePaid == true {
                            let endDate = home.openHouseEndDate ?? openHouseDate.addingTimeInterval(7200) // Default 2 hours
                            if endDate > Date() {
                                Text("OPEN HOUSE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Line 2: Address
                    if let address = home.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else if let city = home.city, let state = home.state {
                        Text("\(city), \(state)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Always show menu button (options differ based on post ownership)
                Button(action: {
                    showMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Tags
            if let tags = home.tags, !tags.isEmpty {
                TagListView(tags: tags, maxTags: 4) { tag in
                    // Filter feed by tag
                    searchText = tag
                    print("🏷️ Tapped tag: \(tag) - Filtering feed")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Image Carousel
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack {
                        TabView(selection: $currentPhotoIndex) {
                            ForEach(Array(home.imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .overlay(ProgressView())
                                }
                                .tag(index)
                                .onTapGesture(count: 2) {
                                    // Double tap to like
                                    if !isLiked {
                                        toggleLike()
                                    }
                                    // Show heart animation
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        showHeartAnimation = true
                                    }
                                    // Hide after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation {
                                            showHeartAnimation = false
                                        }
                                    }
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                        // Heart animation overlay
                        if showHeartAnimation {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                                .scaleEffect(showHeartAnimation ? 1.0 : 0.5)
                                .opacity(showHeartAnimation ? 1.0 : 0.0)
                        }

                        // Calendar button overlay - COMMENTED OUT for App Store submission
                        // TODO: Re-enable once fully tested
//                        if let openHouseDate = home.openHouseDate, home.openHousePaid == true {
//                            let endDate = home.openHouseEndDate ?? openHouseDate.addingTimeInterval(7200)
//                            if endDate > Date() {
//                                VStack {
//                                    HStack {
//                                        Spacer()
//                                        Button(action: {
//                                            toggleOpenHouseSaved()
//                                        }) {
//                                            Image(systemName: isOpenHouseSaved ? "calendar.badge.checkmark" : "calendar.badge.plus")
//                                                .font(.system(size: 28))
//                                                .foregroundColor(.white)
//                                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
//                                                .padding(12)
//                                                .background(
//                                                    Circle()
//                                                        .fill(isOpenHouseSaved ? Color.green.opacity(0.9) : Color.green.opacity(0.7))
//                                                )
//                                        }
//                                        .padding(.trailing, 12)
//                                        .padding(.top, 12)
//                                    }
//                                    Spacer()
//                                }
//                            }
//                        }
                    }
                }
                .frame(height: 400)

                // Photo indicator dots - Progressive sizing (gets smaller to indicate more photos)
                if home.imageUrls.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<min(home.imageUrls.count, 5), id: \.self) { index in
                            let isActive = currentPhotoIndex == index
                            let size = getDotSize(for: index, isActive: isActive, totalDots: min(home.imageUrls.count, 5))
                            Circle()
                                .fill(isActive ? Color.orange : Color.gray.opacity(0.5))
                                .frame(width: size, height: size)
                        }
                        // Show ellipsis if more than 5 photos
                        if home.imageUrls.count > 5 {
                            Text("...")
                                .font(.system(size: 8))
                                .foregroundColor(.gray.opacity(0.5))
                                .offset(y: -2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))
                }
            }

            // Action buttons
            HStack(spacing: 16) {
                // Like button
                Button(action: {
                    toggleLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(isLiked ? .red : .black)
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                    }
                }

                // Comment button
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.title3)
                        if home.commentsCount > 0 {
                            Text("\(home.commentsCount)")
                                .font(.subheadline)
                        }
                    }
                }

                // Share button
                Button(action: {
                    shareHome()
                    showShareSheet = true
                }) {
                    Image(systemName: "paperplane")
                        .font(.title3)
                }

                // Message button - COMMENTED OUT (not requested to be re-enabled)
                // if let profile = home.profile, let currentId = currentUserId, profile.id != currentId {
                //     Button(action: {
                //         showChat = true
                //     }) {
                //         Image(systemName: "message")
                //             .font(.title3)
                //     }
                // }

                Spacer()
            }
            .foregroundColor(.black)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Property details (bed/bath/price)
            HStack(spacing: 12) {
                // Username (clickable to profile)
                NavigationLink(destination: ProfileView(viewingUserId: home.userId)) {
                    Text("\(home.profile?.username ?? "user")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                // Bedrooms
                if let bedrooms = home.bedrooms {
                    HStack(spacing: 4) {
                        Image(systemName: "bed.double.fill")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("\(bedrooms)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                // Bathrooms
                if let bathrooms = home.bathrooms {
                    HStack(spacing: 4) {
                        Image(systemName: "shower.fill")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f", Double(truncating: bathrooms as NSNumber)))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                // Price (single dollar sign)
                if let price = home.price {
                    let priceInt = Int(truncating: price as NSNumber)
                    Text("\(formatPrice(priceInt))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 2)

            // View comments button
            if home.commentsCount > 0 {
                Button(action: {
                    showComments = true
                }) {
                    Text("View all \(home.commentsCount) comments")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Time ago
            Text(timeAgo(from: home.createdAt))
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(home: home)
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.67)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showChat) {
            if let profile = home.profile {
                ChatView(
                    otherUserId: profile.id,
                    otherUsername: profile.username,
                    otherAvatarUrl: profile.avatarUrl
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(home: home)
        }
        .onAppear {
            // Only load user ID if not preloaded
            if currentUserId == nil {
                loadCurrentUserId()
            }
            // Load existing price vote and community price
            loadPriceVote()
            // Check if open house is saved
            checkIfOpenHouseSaved()
        }
        .confirmationDialog("Post Options", isPresented: $showMenu, titleVisibility: .hidden) {
            let _ = print("🔧 Menu opened - currentUserId: \(currentUserId?.uuidString ?? "nil"), homeUserId: \(home.userId.uuidString), showSoldOptions: \(showSoldOptions), soldStatus: \(soldStatus ?? "nil")")
            // Only show edit/delete if current user owns the post
            if currentUserId == home.userId {
                Button("Edit Post") {
                    showEditPost = true
                }

                // Show sold/leased/pending options only in profile view
                if showSoldOptions && soldStatus == nil {
                    Button("Mark as Pending") {
                        print("🟡 Mark as Pending button tapped")
                        markAsSoldOrLeased(status: "pending")
                    }
                    Button("Mark as Leased") {
                        print("🔵 Mark as Leased button tapped")
                        markAsSoldOrLeased(status: "leased")
                    }
                    Button("Mark as Sold") {
                        print("🔴 Mark as Sold button tapped")
                        markAsSoldOrLeased(status: "sold")
                    }
                }

                // Option to remove sold/leased status
                if showSoldOptions && soldStatus != nil {
                    Button("Remove \(soldStatus?.capitalized ?? "") Status") {
                        removeSoldStatus()
                    }
                }

                // Option to cancel open house
                if home.openHousePaid == true, let openHouseDate = home.openHouseDate {
                    let endDate = home.openHouseEndDate ?? openHouseDate.addingTimeInterval(7200)
                    if endDate > Date() {
                        Button("Cancel Open House", role: .destructive) {
                            cancelOpenHouse()
                        }
                    }
                }

                Button("Delete Post", role: .destructive) {
                    showDeleteAlert = true
                }
            } else {
                // Moderation options for posts from other users
                Button("Report Post") {
                    showReportDialog = true
                }

                Button("Block User") {
                    showBlockAlert = true
                }

                Button("Hide Post") {
                    showHideAlert = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditPost) {
            CreatePostView(editingHome: home)
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        // Report Post Dialog
        .confirmationDialog("Report Post", isPresented: $showReportDialog, titleVisibility: .visible) {
            Button("Spam or Scam") {
                reportPost(reason: "Spam or Scam")
            }
            Button("Harassment or Hate Speech") {
                reportPost(reason: "Harassment or Hate Speech")
            }
            Button("Inappropriate Content") {
                reportPost(reason: "Inappropriate Content")
            }
            Button("Misleading Information") {
                reportPost(reason: "Misleading Information")
            }
            Button("Copyright Infringement") {
                reportPost(reason: "Copyright Infringement")
            }
            Button("Other") {
                reportPost(reason: "Other")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Why are you reporting this post? Our moderation team will review all reports within 24 hours. Violating content will be removed and users who violate our community guidelines will be removed from the platform.")
        }
        // Block User Alert
        .alert("Block User", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block @\(home.profile?.username ?? "this user")? You won't see their posts anymore.")
        }
        // Hide Post Alert
        .alert("Hide Post", isPresented: $showHideAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Hide") {
                hidePost()
            }
        } message: {
            Text("Hide this post from your feed? You can always undo this later.")
        }
        // Report Confirmation Alert
        .alert("Report Submitted", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you for your report. Our moderation team will review this content within 24 hours and take appropriate action.")
        }
        // Block Confirmation Alert
        .alert("User Blocked", isPresented: $showBlockConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have successfully blocked this user. You won't see their posts anymore.")
        }
        // Hide Confirmation Alert
        .alert("Post Hidden", isPresented: $showHideConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This post has been hidden from your feed.")
        }
        .overlay(
            Group {
                if showOpenHouseSavedMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                            Text(isOpenHouseSaved ? "Added to Open Houses" : "Removed from Open Houses")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: showOpenHouseSavedMessage)
                }
            }
        )
    }

    func checkIfLiked() {
        // Skip if already checked
        if hasCheckedLike {
            return
        }
        hasCheckedLike = true
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct LikeCheck: Codable {
                    let id: UUID
                }

                let response: [LikeCheck] = try await SupabaseManager.shared.client
                    .from("likes")
                    .select("id")
                    .eq("home_id", value: home.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                isLiked = !response.isEmpty
                print(isLiked ? "✅ Post is liked" : "ℹ️ Post is not liked")
            } catch {
                print("❌ Error checking like status: \(error)")
            }
        }
    }

    func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else {
            return "Just now"
        }
    }

    func toggleLike() {
        print("🔄 Toggle like called - current state: \(isLiked)")

        // Check like status on first interaction if not already checked
        if !hasCheckedLike {
            checkIfLiked()
        }

        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        Task {
            do {
                print("🔐 Getting user session...")
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("✅ User ID: \(userId)")

                if isLiked {
                    // Create like
                    print("❤️ Creating like for home: \(home.id)")
                    struct NewLike: Encodable {
                        let home_id: String
                        let user_id: String
                    }

                    try await SupabaseManager.shared.client
                        .from("likes")
                        .insert(NewLike(home_id: home.id.uuidString, user_id: userId.uuidString))
                        .execute()
                    print("✅ Liked post successfully")

                    // Create notification for post owner (don't notify yourself)
                    if home.userId != userId {
                        struct UsernameResponse: Codable {
                            let username: String
                        }

                        let currentUsername = try? await SupabaseManager.shared.client
                            .from("profiles")
                            .select("username")
                            .eq("id", value: userId.uuidString)
                            .single()
                            .execute()
                            .value as UsernameResponse

                        struct NewNotification: Encodable {
                            let user_id: String
                            let triggered_by_user_id: String
                            let type: String
                            let title: String
                            let message: String
                            let home_id: String
                        }

                        let username = currentUsername?.username ?? "Someone"
                        let notification = NewNotification(
                            user_id: home.userId.uuidString,
                            triggered_by_user_id: userId.uuidString,
                            type: "like",
                            title: "New Like",
                            message: "\(username) liked your post",
                            home_id: home.id.uuidString
                        )

                        _ = try? await SupabaseManager.shared.client
                            .from("notifications")
                            .insert(notification)
                            .execute()
                        print("✅ Created like notification")
                    }
                } else {
                    // Delete like
                    print("💔 Deleting like for home: \(home.id)")
                    try await SupabaseManager.shared.client
                        .from("likes")
                        .delete()
                        .eq("home_id", value: home.id.uuidString)
                        .eq("user_id", value: userId.uuidString)
                        .execute()
                    print("✅ Unliked post successfully")
                }
            } catch {
                print("❌ Error toggling like: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                // Revert on error
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
            }
        }
    }

    func shareHome() {
        // Track share in database
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct NewShare: Encodable {
                    let home_id: String
                    let user_id: String
                }

                try await SupabaseManager.shared.client
                    .from("shares")
                    .insert(NewShare(home_id: home.id.uuidString, user_id: userId.uuidString))
                    .execute()
                print("✅ Share tracked successfully")
            } catch {
                print("❌ Error tracking share: \(error)")
            }
        }
    }

    func loadCurrentUserId() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                currentUserId = userId
            } catch {
                print("❌ Error loading current user ID: \(error)")
            }
        }
    }

    func deletePost() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("🗑️ Deleting post: \(home.id)")

                // Check if user owns this post
                if home.userId != userId {
                    print("❌ User does not own this post")
                    return
                }

                // Delete the post (cascade will handle likes and comments)
                try await SupabaseManager.shared.client
                    .from("homes")
                    .delete()
                    .eq("id", value: home.id.uuidString)
                    .execute()

                print("✅ Post deleted successfully")

                // Post notifications to refresh feed and profile
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshProfile"), object: nil)
            } catch {
                print("❌ Error deleting post: \(error)")
            }
        }
    }

    func markAsSoldOrLeased(status: String) {
        print("🔧 markAsSoldOrLeased called with status: \(status)")
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("🔧 Current user ID: \(userId), Post owner ID: \(home.userId)")

                // Check if user owns this post
                if home.userId != userId {
                    print("❌ User does not own this post")
                    return
                }

                print("🔧 User owns post, updating status to: \(status)")

                struct SoldStatusUpdate: Encodable {
                    let sold_status: String
                    let sold_date: Date
                    let updated_at: Date
                }

                let update = SoldStatusUpdate(
                    sold_status: status,
                    sold_date: Date(),
                    updated_at: Date()
                )

                print("🔧 Sending update to Supabase...")
                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                print("✅ Post marked as \(status)")

                // Wait for database to propagate before refreshing
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Post notifications to refresh feed and profile on main thread
                await MainActor.run {
                    print("🔄 Posting refresh notifications...")
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshProfile"), object: nil)
                }
            } catch {
                print("❌ Error marking post as \(status): \(error)")
            }
        }
    }

    func removeSoldStatus() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Check if user owns this post
                if home.userId != userId {
                    print("❌ User does not own this post")
                    return
                }

                print("🔧 BEFORE UPDATE - Current badge status: \(soldStatus ?? "nil")")
                print("🔧 Updating home ID: \(home.id.uuidString)")

                // CRITICAL FIX: Custom encodable that explicitly encodes nil as JSON null
                struct SoldStatusUpdate: Encodable {
                    let sold_status: String?
                    let sold_date: String?
                    let updated_at: Date

                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        // Explicitly encode nil as null (not omit the key)
                        try container.encode(sold_status, forKey: .sold_status)
                        try container.encode(sold_date, forKey: .sold_date)
                        try container.encode(updated_at, forKey: .updated_at)
                    }

                    enum CodingKeys: String, CodingKey {
                        case sold_status, sold_date, updated_at
                    }
                }

                let update = SoldStatusUpdate(
                    sold_status: nil,
                    sold_date: nil,
                    updated_at: Date()
                )

                print("🔧 Sending update with explicit NULL values for sold_status and sold_date")

                // Execute update
                let response = try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                print("✅ Database update response received")
                print("🔧 Response status: \(response.response.statusCode)")

                // Immediately update local state to remove badge
                await MainActor.run {
                    soldStatus = nil
                    soldDate = nil
                    print("🔧 Local state cleared - soldStatus is now: \(soldStatus ?? "nil")")
                }

                // Wait longer for database to propagate
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                // Post notifications to refresh feed and profile on main thread
                await MainActor.run {
                    print("🔄 Posting refresh notifications...")
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshProfile"), object: nil)
                }

                print("✅ Sold/leased status removed successfully")
            } catch {
                print("❌ Error removing sold status: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Moderation Functions

    func reportPost(reason: String) {
        Task {
            do {
                guard let reporterId = try? await SupabaseManager.shared.client.auth.session.user.id else {
                    print("❌ Not authenticated")
                    return
                }

                print("📢 Reporting post - Reason: \(reason)")

                struct ReportData: Encodable {
                    let home_id: String
                    let reporter_id: String
                    let reported_user_id: String
                    let reason: String
                    let status: String
                }

                let report = ReportData(
                    home_id: home.id.uuidString,
                    reporter_id: reporterId.uuidString,
                    reported_user_id: home.userId.uuidString,
                    reason: reason,
                    status: "pending"
                )

                try await SupabaseManager.shared.client
                    .from("reports")
                    .insert(report)
                    .execute()

                print("✅ Post reported successfully")

                // Show confirmation message
                await MainActor.run {
                    showReportConfirmation = true
                }
            } catch {
                print("❌ Error reporting post: \(error)")
            }
        }
    }

    func blockUser() {
        Task {
            do {
                guard let blockerId = try? await SupabaseManager.shared.client.auth.session.user.id else {
                    print("❌ Not authenticated")
                    return
                }

                print("🚫 Blocking user: @\(home.profile?.username ?? "unknown")")

                struct BlockData: Encodable {
                    let blocker_id: String
                    let blocked_id: String
                }

                let block = BlockData(
                    blocker_id: blockerId.uuidString,
                    blocked_id: home.userId.uuidString
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

    func hidePost() {
        Task {
            do {
                guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
                    print("❌ Not authenticated")
                    return
                }

                print("👁️ Hiding post")

                struct HideData: Encodable {
                    let user_id: String
                    let home_id: String
                }

                let hide = HideData(
                    user_id: userId.uuidString,
                    home_id: home.id.uuidString
                )

                try await SupabaseManager.shared.client
                    .from("hidden_posts")
                    .insert(hide)
                    .execute()

                print("✅ Post hidden successfully")

                // Show confirmation message
                await MainActor.run {
                    showHideConfirmation = true
                }

                // Post notification to refresh feed (remove hidden post)
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
            } catch {
                print("❌ Error hiding post: \(error)")
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func formatOpenHouse(date: Date, endDate: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        var result = formatter.string(from: date)

        if let end = endDate {
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "h:mm a"
            result += " - \(endFormatter.string(from: end))"
        }

        return result
    }

    // Format price with commas (Int version for estimator)
    func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return "$" + (formatter.string(from: NSNumber(value: price)) ?? "\(price)")
    }

    // Format price with commas (Decimal version for list price)
    func formatPriceFromDecimal(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let nsDecimal = NSDecimalNumber(decimal: price)
        return "$" + (formatter.string(from: nsDecimal) ?? "\(price)")
    }

    // Calculate dot size with progressive sizing (dots get smaller to indicate more photos)
    func getDotSize(for index: Int, isActive: Bool, totalDots: Int) -> CGFloat {
        let baseSize: CGFloat = isActive ? 8 : 6

        // If 5 or fewer dots, use gradual scaling from index 3 onwards
        if totalDots <= 5 {
            if index < 3 {
                return baseSize
            } else if index == 3 {
                return baseSize * 0.75  // 75% of normal size
            } else {
                return baseSize * 0.6   // 60% of normal size
            }
        }

        // For more than 5 dots, scale the last two
        if index < 3 {
            return baseSize
        } else if index == 3 {
            return baseSize * 0.75
        } else {
            return baseSize * 0.6
        }
    }

    // MARK: - Price Voting Functions

    func loadPriceVote() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct PriceVote: Codable {
                    let voteType: String

                    enum CodingKeys: String, CodingKey {
                        case voteType = "vote_type"
                    }
                }

                let response: [PriceVote] = try await SupabaseManager.shared.client
                    .from("price_votes")
                    .select("vote_type")
                    .eq("home_id", value: home.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                if let vote = response.first {
                    upVoted = vote.voteType == "up"
                    downVoted = vote.voteType == "down"
                    print("📊 User has voted: \(vote.voteType)")
                }

                // Load community-adjusted price
                loadCommunityPrice()
            } catch {
                print("❌ Error loading price vote: \(error)")
            }
        }
    }

    func submitPriceVote(voteType: String) {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct PriceVoteInsert: Encodable {
                    let homeId: String
                    let userId: String
                    let voteType: String

                    enum CodingKeys: String, CodingKey {
                        case homeId = "home_id"
                        case userId = "user_id"
                        case voteType = "vote_type"
                    }
                }

                let vote = PriceVoteInsert(
                    homeId: home.id.uuidString,
                    userId: userId.uuidString,
                    voteType: voteType
                )

                try await SupabaseManager.shared.client
                    .from("price_votes")
                    .upsert(vote)
                    .execute()

                // Update local state
                if voteType == "up" {
                    upVoted = true
                    downVoted = false
                } else {
                    downVoted = true
                    upVoted = false
                }

                print("✅ Price vote submitted: \(voteType)")

                // Reload community price to see the effect
                loadCommunityPrice()
            } catch {
                print("❌ Error submitting price vote: \(error)")
            }
        }
    }

    func loadCommunityPrice() {
        guard home.price != nil else { return }

        Task {
            do {
                print("🔄 Loading community price for home: \(home.id)")

                // RPC functions return values directly, not wrapped in objects
                let response: Decimal = try await SupabaseManager.shared.client
                    .rpc("get_community_price", params: ["home_id_param": home.id.uuidString])
                    .single()
                    .execute()
                    .value

                estimatedPrice = NSDecimalNumber(decimal: response).intValue
                print("📊 Community price loaded: $\(estimatedPrice) (original: $\(NSDecimalNumber(decimal: home.price ?? 0).intValue))")
            } catch {
                print("❌ Error loading community price: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                // Fallback to original price if community price fails
                estimatedPrice = NSDecimalNumber(decimal: home.price ?? 0).intValue
            }
        }
    }

    // MARK: - Open House Saved Functions

    func checkIfOpenHouseSaved() {
        // Only check if this is an open house post
        guard let openHouseDate = home.openHouseDate, home.openHousePaid == true else {
            return
        }

        let endDate = home.openHouseEndDate ?? openHouseDate.addingTimeInterval(7200)
        guard endDate > Date() else {
            return
        }

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct SavedOpenHouseCheck: Codable {
                    let id: UUID
                }

                let response: [SavedOpenHouseCheck] = try await SupabaseManager.shared.client
                    .from("saved_open_houses")
                    .select("id")
                    .eq("home_id", value: home.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                isOpenHouseSaved = !response.isEmpty
                print(isOpenHouseSaved ? "📅 Open house is saved" : "ℹ️ Open house is not saved")
            } catch {
                print("❌ Error checking saved open house status: \(error)")
            }
        }
    }

    func toggleOpenHouseSaved() {
        print("📅 Toggle open house saved called - current state: \(isOpenHouseSaved)")

        isOpenHouseSaved.toggle()

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                if isOpenHouseSaved {
                    // Save open house
                    print("📅 Saving open house for home: \(home.id)")
                    struct NewSavedOpenHouse: Encodable {
                        let home_id: String
                        let user_id: String
                    }

                    try await SupabaseManager.shared.client
                        .from("saved_open_houses")
                        .insert(NewSavedOpenHouse(home_id: home.id.uuidString, user_id: userId.uuidString))
                        .execute()
                    print("✅ Open house saved successfully")

                    // Post notification to refresh open house list
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshOpenHouseList"), object: nil)
                } else {
                    // Unsave open house
                    print("📅 Removing saved open house for home: \(home.id)")
                    try await SupabaseManager.shared.client
                        .from("saved_open_houses")
                        .delete()
                        .eq("home_id", value: home.id.uuidString)
                        .eq("user_id", value: userId.uuidString)
                        .execute()
                    print("✅ Open house unsaved successfully")

                    // Post notification to refresh open house list
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshOpenHouseList"), object: nil)
                }

                // Show success message
                await MainActor.run {
                    withAnimation {
                        showOpenHouseSavedMessage = true
                    }
                }

                // Hide message after 2 seconds
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation {
                        showOpenHouseSavedMessage = false
                    }
                }
            } catch {
                print("❌ Error toggling saved open house: \(error)")
                // Revert on error
                await MainActor.run {
                    isOpenHouseSaved.toggle()
                }
            }
        }
    }

    // MARK: - Cancel Open House

    func cancelOpenHouse() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Check if user owns this post
                if home.userId != userId {
                    print("❌ User does not own this post")
                    return
                }

                print("🚫 Cancelling open house for home: \(home.id)")

                // Get all users who saved this open house
                struct SavedBy: Codable {
                    let userId: UUID

                    enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                    }
                }

                let savedByUsers: [SavedBy] = try await SupabaseManager.shared.client
                    .from("saved_open_houses")
                    .select("user_id")
                    .eq("home_id", value: home.id.uuidString)
                    .execute()
                    .value

                print("📢 Notifying \(savedByUsers.count) users who saved this open house")

                // Create notifications for each user who saved it
                for savedUser in savedByUsers {
                    struct NewNotification: Encodable {
                        let user_id: String
                        let triggered_by_user_id: String
                        let type: String
                        let title: String
                        let message: String
                        let home_id: String
                    }

                    let address = home.address ?? "a property"
                    let notification = NewNotification(
                        user_id: savedUser.userId.uuidString,
                        triggered_by_user_id: userId.uuidString,
                        type: "open_house_cancelled",
                        title: "Open House Cancelled",
                        message: "The open house at \(address) has been cancelled by the owner.",
                        home_id: home.id.uuidString
                    )

                    try await SupabaseManager.shared.client
                        .from("notifications")
                        .insert(notification)
                        .execute()
                }

                // Update the home to remove open house info
                struct OpenHouseUpdate: Encodable {
                    let open_house_paid: Bool?
                    let open_house_date: Date?
                    let open_house_end_date: Date?
                    let stripe_payment_id: String?
                }

                let update = OpenHouseUpdate(
                    open_house_paid: nil,
                    open_house_date: nil,
                    open_house_end_date: nil,
                    stripe_payment_id: nil
                )

                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                print("✅ Open house cancelled successfully")

                // Post notifications to refresh
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshProfile"), object: nil)
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshOpenHouseList"), object: nil)
            } catch {
                print("❌ Error cancelling open house: \(error)")
            }
        }
    }
}

// MARK: - Loading Skeleton View
struct LoadingSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (profile pic + username + location)
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .shimmer(isAnimating: isAnimating)

                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 12)
                        .shimmer(isAnimating: isAnimating)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 10)
                        .shimmer(isAnimating: isAnimating)
                }

                Spacer()

                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .shimmer(isAnimating: isAnimating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Image placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 400)
                .shimmer(isAnimating: isAnimating)

            // Action buttons
            HStack(spacing: 16) {
                // Heart
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 24)
                    .shimmer(isAnimating: isAnimating)

                // Comment
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 24)
                    .shimmer(isAnimating: isAnimating)

                // Share
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 24)
                    .shimmer(isAnimating: isAnimating)

                // Message
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 24)
                    .shimmer(isAnimating: isAnimating)

                Spacer()

                // Price voting
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 90, height: 24)
                    .shimmer(isAnimating: isAnimating)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Caption
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 250, height: 12)
                    .shimmer(isAnimating: isAnimating)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)

            // Bedrooms/Bathrooms info
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 12)
                    .shimmer(isAnimating: isAnimating)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 12)
                    .shimmer(isAnimating: isAnimating)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 12)
                    .shimmer(isAnimating: isAnimating)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Shimmer Effect Modifier
struct ShimmerModifier: ViewModifier {
    let isAnimating: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                if isAnimating {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                }
            }
    }
}

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        modifier(ShimmerModifier(isAnimating: isAnimating))
    }
}

#Preview {
    FeedView()
}

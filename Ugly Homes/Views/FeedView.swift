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
    @State private var isLoading = false
    @State private var showCreatePost = false
    @State private var searchText = ""

    var filteredHomes: [Home] {
        if searchText.isEmpty {
            return homes
        } else {
            return allHomes.filter { home in
                // Search by username
                if let username = home.profile?.username, username.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                // Search by address
                if let address = home.address, address.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                // Search by city
                if let city = home.city, city.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                // Search by state
                if let state = home.state, state.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                // Search by zip code
                if let zipCode = home.zipCode, zipCode.contains(searchText) {
                    return true
                }
                return false
            }
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

                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
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

                    Button(action: {
                        showCreatePost = true
                    }) {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Content
                ZStack {
                    if filteredHomes.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: searchText.isEmpty ? "house.slash" : "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text(searchText.isEmpty ? "No homes yet" : "No results found")
                                .font(.title2)
                                .foregroundColor(.gray)
                            if searchText.isEmpty {
                                Text("Be the first to post an ugly home!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredHomes) { home in
                                    HomePostView(home: home)
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
            .onChange(of: showCreatePost) { oldValue, newValue in
                if !newValue {
                    // Refresh feed when create post sheet is dismissed
                    loadHomes()
                }
            }
            .onAppear {
                loadHomes()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFeed"))) { _ in
                loadHomes()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
                loadHomes() // Reload to get updated profile photos
            }
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func loadHomes() {
        isLoading = true

        Task {
            do {
                print("📥 Loading trending homes with algorithm...")

                // Get current user ID
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("👤 Current user ID: \(userId)")

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
                    let viewCount: Int?
                    let shareCount: Int?
                    let saveCount: Int?
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
                        case viewCount = "view_count"
                        case shareCount = "share_count"
                        case saveCount = "save_count"
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
                        case createdAt = "created_at"
                        case updatedAt = "updated_at"
                        case trendingScore = "trending_score"
                    }
                }

                let response: [TrendingHomeResponse] = try await SupabaseManager.shared.client
                    .rpc("get_trending_homes", params: ["current_user_id": userId.uuidString])
                    .execute()
                    .value

                print("✅ Loaded \(response.count) trending homes")

                // OPTIMIZATION: Fetch all profiles in a single query instead of one-by-one
                struct ProfileResponse: Codable {
                    let id: UUID
                    let username: String
                    let fullName: String?
                    let avatarUrl: String?
                    let bio: String?
                    let createdAt: Date
                    let updatedAt: Date

                    enum CodingKeys: String, CodingKey {
                        case id
                        case username
                        case fullName = "full_name"
                        case avatarUrl = "avatar_url"
                        case bio
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
                        viewCount: homeResponse.viewCount,
                        shareCount: homeResponse.shareCount,
                        saveCount: homeResponse.saveCount,
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
                        createdAt: homeResponse.createdAt,
                        updatedAt: homeResponse.updatedAt
                    )
                    // Look up profile from dictionary (O(1) instead of network call)
                    home.profile = profilesDict[homeResponse.userId]
                    homesWithProfiles.append(home)
                }

                homes = homesWithProfiles
                allHomes = homesWithProfiles

                // Print trending scores for debugging
                for (index, homeResponse) in response.prefix(5).enumerated() {
                    print("📊 #\(index + 1): \(homeResponse.title) - Score: \(homeResponse.trendingScore)")
                }

                isLoading = false
            } catch {
                print("❌ Error loading trending homes: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
}

struct HomePostView: View {
    let home: Home
    let showSoldOptions: Bool
    let preloadedUserId: UUID?
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

    // User-generated pricing feature
    @State private var upVoted = false
    @State private var downVoted = false
    @State private var estimatedPrice: Int

    init(home: Home, showSoldOptions: Bool = false, preloadedUserId: UUID? = nil) {
        self.home = home
        self.showSoldOptions = showSoldOptions
        self.preloadedUserId = preloadedUserId
        _likeCount = State(initialValue: home.likesCount)
        _estimatedPrice = State(initialValue: NSDecimalNumber(decimal: home.price ?? 0).intValue)
        _soldStatus = State(initialValue: home.soldStatus)
        _soldDate = State(initialValue: home.soldDate)
        _currentUserId = State(initialValue: preloadedUserId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            HStack {
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

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(home.profile?.username ?? "User")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        // Sold/Leased badge
                        if let status = soldStatus {
                            Text(status.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(status == "sold" ? Color.red : Color.blue)
                                .cornerRadius(4)
                        }

                        // Open House badge (gold) - only show if date hasn't passed
                        if let openHouseDate = home.openHouseDate, home.openHousePaid == true {
                            let endDate = home.openHouseEndDate ?? openHouseDate.addingTimeInterval(7200) // Default 2 hours
                            if endDate > Date() {
                                Text("OPEN HOUSE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Show address, city format (e.g., "123 Main St, San Francisco")
                    if let address = home.address, !address.isEmpty, let city = home.city {
                        Text("\(address), \(city)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else if let city = home.city, let state = home.state {
                        Text("\(city), \(state)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Show sold/leased date
                    if let status = soldStatus, let date = soldDate {
                        Text("\(status == "sold" ? "Sold" : "Leased") on \(formatDate(date))")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    // Show open house date/time - only if hasn't expired
                    if let openHouseDate = home.openHouseDate, home.openHousePaid == true {
                        let endDate = home.openHouseEndDate ?? openHouseDate.addingTimeInterval(7200)
                        if endDate > Date() {
                            Text("Open House: \(formatOpenHouse(date: openHouseDate, endDate: home.openHouseEndDate))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        }
                    }
                }

                Spacer()

                Button(action: {
                    showMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

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
                    }
                }
                .frame(height: 400)

                // Photo indicator dots - 3 dots: first, middle, last
                if home.imageUrls.count > 1 {
                    HStack(spacing: 5) {
                        // First dot
                        Circle()
                            .fill(currentPhotoIndex == 0 ? Color.orange : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)

                        // Middle dot
                        Circle()
                            .fill((currentPhotoIndex > 0 && currentPhotoIndex < home.imageUrls.count - 1) ? Color.orange : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)

                        // Last dot
                        Circle()
                            .fill(currentPhotoIndex == home.imageUrls.count - 1 ? Color.orange : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
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
                }) {
                    Image(systemName: "paperplane")
                        .font(.title3)
                }

                // Message button (only show if not own post)
                if let profile = home.profile, let currentId = currentUserId, profile.id != currentId {
                    Button(action: {
                        showChat = true
                    }) {
                        Image(systemName: "message")
                            .font(.title3)
                    }
                }

                Spacer()

                // User-Generated Pricing Feature - Right Side
                if home.price != nil {
                    HStack(spacing: 4) {
                        // Up arrow button
                        Button(action: {
                            if !upVoted {
                                upVoted = true
                                estimatedPrice = Int(Double(estimatedPrice) * 1.005)
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.title3)
                                .foregroundColor(upVoted ? .gray.opacity(0.5) : .black)
                        }
                        .disabled(upVoted)

                        // Estimated price in orange (bold with commas)
                        Text(formatPrice(estimatedPrice))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)

                        // Down arrow button
                        Button(action: {
                            if !downVoted {
                                downVoted = true
                                estimatedPrice = Int(Double(estimatedPrice) * 0.995)
                            }
                        }) {
                            Image(systemName: "arrow.down")
                                .font(.title3)
                                .foregroundColor(downVoted ? .gray.opacity(0.5) : .black)
                        }
                        .disabled(downVoted)
                    }
                }
            }
            .foregroundColor(.black)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Caption
            HStack(alignment: .top) {
                Text(home.profile?.username ?? "User")
                    .fontWeight(.semibold)
                + Text(" ")
                + Text(home.title)
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.top, 2)

            // Bedrooms, Bathrooms, and Price
            HStack(spacing: 16) {
                if let bedrooms = home.bedrooms {
                    HStack(spacing: 5) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 14))
                        Text("\(bedrooms) bd")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }

                if let bathrooms = home.bathrooms {
                    HStack(spacing: 5) {
                        Image(systemName: "shower.fill")
                            .font(.system(size: 14))
                        Text("\(NSDecimalNumber(decimal: bathrooms).doubleValue, specifier: "%.1f") ba")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }

                if let price = home.price {
                    Text(formatPriceFromDecimal(price))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 6)

            // View comments
            if home.commentsCount > 0 {
                Button(action: {
                    showComments = true
                }) {
                    Text("View all \(home.commentsCount) comments")
                        .font(.caption)
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
        .onAppear {
            // Only load user ID if not preloaded
            if currentUserId == nil {
                loadCurrentUserId()
            }
        }
        .confirmationDialog("Post Options", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Edit Post") {
                showEditPost = true
            }

            // Show sold/leased options only in profile view
            if showSoldOptions && soldStatus == nil {
                Button("Mark as Leased") {
                    markAsSoldOrLeased(status: "leased")
                }
                Button("Mark as Sold") {
                    markAsSoldOrLeased(status: "sold")
                }
            }

            // Option to remove sold/leased status
            if showSoldOptions && soldStatus != nil {
                Button("Remove \(soldStatus?.capitalized ?? "") Status") {
                    removeSoldStatus()
                }
            }

            Button("Delete Post", role: .destructive) {
                showDeleteAlert = true
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

        let message = """
        Check out this home on Ugly Homes!

        \(home.title)
        \(home.price != nil ? "$\(home.price!)" : "")

        \(home.imageUrls.first ?? "")
        """

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
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

                // Post notification to refresh feed
                NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
            } catch {
                print("❌ Error deleting post: \(error)")
            }
        }
    }

    func markAsSoldOrLeased(status: String) {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Check if user owns this post
                if home.userId != userId {
                    print("❌ User does not own this post")
                    return
                }

                struct SoldStatusUpdate: Encodable {
                    let sold_status: String
                    let sold_date: Date
                }

                let update = SoldStatusUpdate(
                    sold_status: status,
                    sold_date: Date()
                )

                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                // Update local state
                soldStatus = status
                soldDate = Date()

                print("✅ Post marked as \(status)")

                // Post notification to refresh profile
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
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

                struct SoldStatusUpdate: Encodable {
                    let sold_status: String?
                    let sold_date: Date?
                }

                let update = SoldStatusUpdate(
                    sold_status: nil,
                    sold_date: nil
                )

                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                // Update local state
                soldStatus = nil
                soldDate = nil

                print("✅ Sold/leased status removed")

                // Post notification to refresh profile
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
            } catch {
                print("❌ Error removing sold status: \(error)")
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
}

#Preview {
    FeedView()
}

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
                    if isLoading {
                        ProgressView()
                    } else if filteredHomes.isEmpty {
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
        }
    }

    func loadHomes() {
        isLoading = true

        Task {
            do {
                print("📥 Loading trending homes...")
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .order("likes_count", ascending: false)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) homes")
                homes = response
                allHomes = response
                isLoading = false
            } catch {
                print("❌ Error loading homes: \(error)")
                isLoading = false
            }
        }
    }
}

struct HomePostView: View {
    let home: Home
    @State private var showComments = false
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var currentPhotoIndex = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showMenu = false
    @State private var showDeleteAlert = false
    @State private var showHeartAnimation = false
    @State private var showEditPost = false

    // User-generated pricing feature
    @State private var upVoted = false
    @State private var downVoted = false
    @State private var estimatedPrice: Int

    init(home: Home) {
        self.home = home
        _likeCount = State(initialValue: home.likesCount)
        _estimatedPrice = State(initialValue: home.price ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(home.profile?.username ?? "User")
                        .font(.subheadline)
                        .fontWeight(.semibold)

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

                Spacer()

                // User-Generated Pricing Feature - Right Side
                if home.price != nil {
                    HStack(spacing: 6) {
                        // Up arrow button
                        Button(action: {
                            if !upVoted {
                                upVoted = true
                                estimatedPrice = Int(Double(estimatedPrice) * 1.005)
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(upVoted ? .gray : .white)
                                .frame(width: 32, height: 32)
                                .background(upVoted ? Color.gray.opacity(0.4) : Color.green)
                                .cornerRadius(6)
                        }
                        .disabled(upVoted)

                        // Down arrow button
                        Button(action: {
                            if !downVoted {
                                downVoted = true
                                estimatedPrice = Int(Double(estimatedPrice) * 0.995)
                            }
                        }) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(downVoted ? .gray : .white)
                                .frame(width: 32, height: 32)
                                .background(downVoted ? Color.gray.opacity(0.4) : Color.red)
                                .cornerRadius(6)
                        }
                        .disabled(downVoted)

                        // Estimated price in orange
                        Text("Est. $\(estimatedPrice)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .foregroundColor(.black)
            .padding(.horizontal)
            .padding(.vertical, 12)

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
                    Text("$\(price)")
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
        .confirmationDialog("Post Options", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Edit Post") {
                showEditPost = true
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
        .onAppear {
            checkIfLiked()
        }
    }

    func checkIfLiked() {
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
}

#Preview {
    FeedView()
}

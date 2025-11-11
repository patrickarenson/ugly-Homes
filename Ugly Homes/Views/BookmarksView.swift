//
//  BookmarksView.swift
//  Ugly Homes
//
//  Saved/Bookmarked Homes View
//

import SwiftUI

struct BookmarksView: View {
    @State private var bookmarkedHomes: [Home] = []
    @State private var isLoading = false
    @State private var currentUserId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if bookmarkedHomes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No saved homes yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Tap the bookmark icon on posts to save your favorite homes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 100)
                } else {
                    // Grid of bookmarked homes (same layout as profile)
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 2) {
                        ForEach(bookmarkedHomes) { home in
                            if let imageUrl = home.imageUrls.first {
                                BookmarkGridItem(
                                    home: home,
                                    imageUrl: imageUrl,
                                    currentUserId: currentUserId
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved Homes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBookmarks()
            loadCurrentUserId()
        }
        .refreshable {
            loadBookmarks()
        }
    }

    func loadCurrentUserId() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                await MainActor.run {
                    currentUserId = userId
                }
            } catch {
                print("❌ Error loading current user ID: \(error)")
            }
        }
    }

    func loadBookmarks() {
        isLoading = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

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
                        isLoading = false
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
                    isLoading = false
                }
            } catch {
                print("❌ Error loading bookmarks: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// Separate component to avoid type-check timeout
struct BookmarkGridItem: View {
    let home: Home
    let imageUrl: String
    let currentUserId: UUID?

    var body: some View {
        NavigationLink(destination: PostDetailView(home: home, showSoldOptions: false, preloadedUserId: currentUserId)) {
            ZStack(alignment: .topTrailing) {
                // Image
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        loadingPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        failurePlaceholder
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: UIScreen.main.bounds.width / 3 - 1.5, height: UIScreen.main.bounds.width / 3 - 1.5)
                .clipped()

                // Badges overlay
                VStack(alignment: .trailing, spacing: 4) {
                    soldBadge
                    openHouseBadge
                }
                .padding(6)
            }
        }
    }

    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(1, contentMode: .fill)
    }

    private var failurePlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
            .aspectRatio(1, contentMode: .fill)
    }

    @ViewBuilder
    private var soldBadge: some View {
        if let soldStatus = home.soldStatus {
            Text(soldStatus.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(badgeColor(for: soldStatus))
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private var openHouseBadge: some View {
        if let openHouseDate = home.openHouseDate,
           home.openHousePaid == true,
           openHouseDate > Date() {
            Text("OPEN HOUSE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.green)
                .cornerRadius(4)
        }
    }

    private func badgeColor(for status: String) -> Color {
        switch status {
        case "sold": return .red
        case "leased": return .blue
        case "pending": return .yellow
        default: return .gray
        }
    }
}

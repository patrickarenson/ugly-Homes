//
//  BookmarksView.swift
//  Ugly Homes
//
//  Saved/Bookmarked Homes View
//

import SwiftUI

struct BookmarksView: View {
    @Environment(\.dismiss) var dismiss
    @State private var bookmarkedHomes: [Home] = []
    @State private var isLoading = false
    @State private var currentUserId: UUID?

    var body: some View {
        NavigationView {
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
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .foregroundColor(.gray)
                                                        )
                                                        .aspectRatio(1, contentMode: .fill)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: UIScreen.main.bounds.width / 3 - 1.5, height: UIScreen.main.bounds.width / 3 - 1.5)
                                            .clipped()

                                            VStack(alignment: .trailing, spacing: 4) {
                                                // Sold/Leased/Pending badge overlay
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

                                                // Open House badge
                                                if let openHouse = home.openHouse, openHouse.isActive, openHouse.date > Date() {
                                                    Text("OPEN HOUSE")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Color.green)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            .padding(6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Homes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBookmarks()
                loadCurrentUserId()
            }
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

                // Query bookmarks table and join with homes
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("bookmarks")
                    .select("""
                        home_id,
                        homes:home_id (
                            id,
                            user_id,
                            title,
                            listing_type,
                            description,
                            price,
                            address,
                            unit,
                            city,
                            state,
                            zip_code,
                            bedrooms,
                            bathrooms,
                            image_urls,
                            likes_count,
                            comments_count,
                            shares_count,
                            sold_status,
                            sold_date,
                            is_active,
                            created_at,
                            updated_at,
                            open_house,
                            tags
                        )
                    """)
                    .eq("user_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                await MainActor.run {
                    bookmarkedHomes = response
                    isLoading = false
                }

                print("✅ Loaded \(response.count) bookmarked homes")
            } catch {
                print("❌ Error loading bookmarks: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

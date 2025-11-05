//
//  CommentsView.swift
//  Ugly Homes
//
//  Comments View
//

import SwiftUI
import Foundation

struct CommentsView: View {
    let home: Home
    @Environment(\.dismiss) var dismiss
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var isSending = false

    // Housers Estimate state
    @State private var upVoted = false
    @State private var downVoted = false
    @State private var estimatedPrice: Int

    init(home: Home) {
        self.home = home
        _estimatedPrice = State(initialValue: NSDecimalNumber(decimal: home.price ?? 0).intValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with drag indicator
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Text("Comments")
                    .font(.headline)
                    .padding(.bottom, 8)
            }

            Divider()

            // Property summary
            VStack(alignment: .leading, spacing: 8) {
                // Address (Line 1)
                if let address = home.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else if let city = home.city, let state = home.state {
                    Text("\(city), \(state)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                // Property details - bed/bath (Line 2)
                HStack(spacing: 12) {
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

                Spacer()

                // Housers Estimate on right side
                if home.price != nil {
                    VStack(spacing: 2) {
                        Text("Housers Estimate")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)

                        HStack(spacing: 4) {
                            // Up arrow button
                            Button(action: {
                                submitPriceVote(voteType: "up")
                            }) {
                                Image(systemName: "arrow.up")
                                    .font(.title3)
                                    .foregroundColor(upVoted ? .green : .gray)
                            }
                            .disabled(upVoted || downVoted)

                            // Estimated price
                            Text(formatPrice(estimatedPrice))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)

                            // Down arrow button
                            Button(action: {
                                submitPriceVote(voteType: "down")
                            }) {
                                Image(systemName: "arrow.down")
                                    .font(.title3)
                                    .foregroundColor(downVoted ? .red : .gray)
                            }
                            .disabled(upVoted || downVoted)
                        }
                    }
                }
                }

                // Price (Line 3)
                if let price = home.price {
                    let priceInt = Int(truncating: price as NSNumber)
                    Text("Listed for $\(formatPrice(priceInt))")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            Divider()

            // Comments list
            ScrollView {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if comments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No comments yet")
                                .foregroundColor(.gray)
                            Text("Be the first to comment!")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }

            Divider()

            // Comment input
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )

                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(.plain)

                if !newComment.isEmpty {
                    Button(action: postComment) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    .disabled(isSending)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .onAppear {
            loadComments()
            loadCommunityPrice()
        }
    }

    func loadComments() {
        isLoading = true

        Task {
            do {
                let response: [Comment] = try await SupabaseManager.shared.client
                    .from("comments")
                    .select("*, profile:user_id(*)")
                    .eq("home_id", value: home.id.uuidString)
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                comments = response
                isLoading = false
            } catch {
                print("Error loading comments: \(error)")
                isLoading = false
            }
        }
    }

    func containsURL(_ text: String) -> Bool {
        // Check for common URL patterns
        let lowercaseText = text.lowercased()

        // Check for http:// or https://
        if lowercaseText.contains("http://") || lowercaseText.contains("https://") {
            return true
        }

        // Check for www.
        if lowercaseText.contains("www.") {
            return true
        }

        // Check for common TLDs (top-level domains)
        let tlds = [".com", ".net", ".org", ".io", ".co", ".app", ".dev", ".ai", ".xyz", ".me", ".tv", ".info", ".biz"]
        for tld in tlds {
            if lowercaseText.contains(tld) {
                return true
            }
        }

        return false
    }

    func postComment() {
        guard !newComment.isEmpty else { return }

        // Check for URLs
        if containsURL(newComment) {
            // Silently reject - clear the text field
            newComment = ""
            return
        }

        isSending = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct NewComment: Encodable {
                    let home_id: String
                    let user_id: String
                    let comment_text: String
                }

                let newCommentData = NewComment(
                    home_id: home.id.uuidString,
                    user_id: userId.uuidString,
                    comment_text: newComment
                )

                try await SupabaseManager.shared.client
                    .from("comments")
                    .insert(newCommentData)
                    .execute()

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
                        let type: String
                        let title: String
                        let message: String
                        let home_id: String
                    }

                    let username = currentUsername?.username ?? "Someone"
                    let notification = NewNotification(
                        user_id: home.userId.uuidString,
                        type: "comment",
                        title: "New Comment",
                        message: "\(username) commented on your post",
                        home_id: home.id.uuidString
                    )

                    _ = try? await SupabaseManager.shared.client
                        .from("notifications")
                        .insert(notification)
                        .execute()
                    print("✅ Created comment notification")
                }

                newComment = ""
                isSending = false
                loadComments()

            } catch {
                print("Error posting comment: \(error)")
                isSending = false
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

    func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile photo with navigation
            NavigationLink(destination: {
                if let profile = comment.profile {
                    ProfileView(viewingUserId: profile.id)
                }
            }) {
                if let avatarUrl = comment.profile?.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    NavigationLink(destination: {
                        if let profile = comment.profile {
                            ProfileView(viewingUserId: profile.id)
                        }
                    }) {
                        Text("\(comment.profile?.username ?? "user")")
                            .fontWeight(.semibold)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    Text(timeAgo(from: comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Use MentionText for comment text to make @mentions clickable
                MentionText(
                    text: comment.commentText,
                    font: .subheadline,
                    baseColor: .primary,
                    mentionColor: .blue
                )
            }

            Spacer()
        }
    }

    func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
}

#Preview {
    CommentsView(home: Home(
        id: UUID(),
        userId: UUID(),
        title: "Test Home",
        description: nil,
        price: nil,
        address: nil,
        city: nil,
        state: nil,
        zipCode: nil,
        imageUrls: [],
        likesCount: 0,
        commentsCount: 0,
        isActive: true,
        isArchived: false,
        archivedAt: nil,
        subscriptionId: nil,
        expiresAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    ))
}

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

    // @Mention autocomplete state
    @State private var suggestedUsers: [Profile] = []
    @State private var showingSuggestions = false
    @State private var mentionQuery = ""
    @State private var mentionStartIndex: String.Index?

    // Delete comment state
    @State private var showDeleteAlert = false
    @State private var commentToDelete: Comment?
    @State private var currentUserId: UUID?

    // Error state for moderation
    @State private var showModerationAlert = false
    @State private var moderationErrorMessage = ""

    init(home: Home) {
        self.home = home
        _estimatedPrice = State(initialValue: NSDecimalNumber(decimal: home.price ?? 0).intValue)
        print("🏠 CommentsView INIT - Square Footage: \(home.livingAreaSqft?.description ?? "NIL")")
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
                        .padding(.horizontal)
                } else if let city = home.city, let state = home.state {
                    Text("\(city), \(state)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }

                // Line 2: Bed/Bath on left, Housers Estimate on right
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
                                    handleVote(voteType: "up")
                                }) {
                                    Image(systemName: "arrow.up")
                                        .font(.title3)
                                        .foregroundColor(upVoted ? .green : .gray)
                                }

                                // Estimated price
                                Text(formatPrice(estimatedPrice))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)

                                // Down arrow button
                                Button(action: {
                                    handleVote(voteType: "down")
                                }) {
                                    Image(systemName: "arrow.down")
                                        .font(.title3)
                                        .foregroundColor(downVoted ? .red : .gray)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Line 3: Square footage
                if let sqft = home.livingAreaSqft {
                    let _ = print("✅ DISPLAYING Square Footage: \(sqft) sq ft")
                    Text("\(formatNumber(sqft)) sq ft")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                } else {
                    let _ = print("❌ NO Square Footage to display - home.livingAreaSqft is nil")
                }

                // Line 4: Listed for price
                if let price = home.price {
                    let priceInt = Int(truncating: price as NSNumber)
                    Text("Listed for $\(formatPrice(priceInt))")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
            }
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
                                CommentRow(
                                    comment: comment,
                                    currentUserId: currentUserId,
                                    postOwnerId: home.userId,
                                    onDelete: {
                                        commentToDelete = comment
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        // Dismiss keyboard when scrolling
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )

            Divider()

            // @Mention autocomplete suggestions
            if showingSuggestions && !suggestedUsers.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestedUsers.prefix(5)) { user in
                            Button(action: {
                                selectUser(user)
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(user.username.prefix(1).uppercased())
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("@\(user.username)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        if let fullName = user.fullName, !fullName.isEmpty {
                                            Text(fullName)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                            }
                            .buttonStyle(PlainButtonStyle())

                            if user.id != suggestedUsers.prefix(5).last?.id {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }

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
                    .onChange(of: newComment) { oldValue, newValue in
                        handleTextChange(oldValue: oldValue, newValue: newValue)
                    }

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
            loadCurrentUserId()
            loadUserVoteStatus()
        }
        .alert("Delete Comment", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let comment = commentToDelete {
                    deleteComment(comment)
                }
            }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
        .alert("Comment Blocked", isPresented: $showModerationAlert) {
            Button("OK", role: .cancel) {
                // User can edit their comment and try again
            }
        } message: {
            Text(moderationErrorMessage)
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
                print("Error loading current user ID: \(error)")
            }
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

    func deleteComment(_ comment: Comment) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("comments")
                    .delete()
                    .eq("id", value: comment.id.uuidString)
                    .execute()

                print("✅ Comment deleted successfully")

                // Remove from local state immediately
                await MainActor.run {
                    comments.removeAll { $0.id == comment.id }
                }
            } catch {
                print("❌ Error deleting comment: \(error)")
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

        // CONTENT MODERATION - Check comment text
        let moderationResult = ContentModerationManager.shared.moderateText(newComment)
        switch moderationResult {
        case .blocked(let reason):
            // Block the comment and show alert
            print("🚫 Comment blocked: \(reason)")
            moderationErrorMessage = reason
            showModerationAlert = true
            return

        case .flaggedForReview:
            // Note: We don't mask anymore, but flagged comments could be logged or monitored
            // For now, just let it through
            print("⚠️ Comment flagged but allowed")
            break

        case .approved:
            break
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

                // Get current user's username for notifications
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

                let username = currentUsername?.username ?? "Someone"

                struct NewNotification: Encodable {
                    let user_id: String
                    let triggered_by_user_id: String
                    let type: String
                    let title: String
                    let message: String
                    let home_id: String
                }

                // Extract @mentions from comment
                let mentions = extractMentions(from: newComment)

                // Create notification for each mentioned user
                for mentionedUsername in mentions {
                    // Look up user by username
                    struct UserIdResponse: Codable {
                        let id: String
                    }

                    if let mentionedUser = try? await SupabaseManager.shared.client
                        .from("profiles")
                        .select("id")
                        .eq("username", value: mentionedUsername)
                        .single()
                        .execute()
                        .value as UserIdResponse,
                       mentionedUser.id != userId.uuidString { // Don't notify yourself

                        let mentionNotification = NewNotification(
                            user_id: mentionedUser.id,
                            triggered_by_user_id: userId.uuidString,
                            type: "mention",
                            title: "New Mention",
                            message: "\(username) mentioned you in a comment",
                            home_id: home.id.uuidString
                        )

                        _ = try? await SupabaseManager.shared.client
                            .from("notifications")
                            .insert(mentionNotification)
                            .execute()
                        print("✅ Created mention notification for @\(mentionedUsername)")
                    }
                }

                // Create notification for post owner (don't notify yourself or if already mentioned)
                if home.userId != userId {
                    // Check if post owner was already mentioned
                    var ownerWasMentioned = false
                    if let ownerUsername = try? await SupabaseManager.shared.client
                        .from("profiles")
                        .select("username")
                        .eq("id", value: home.userId.uuidString)
                        .single()
                        .execute()
                        .value as UsernameResponse {
                        ownerWasMentioned = mentions.contains(ownerUsername.username)
                    }

                    if !ownerWasMentioned {
                        let notification = NewNotification(
                            user_id: home.userId.uuidString,
                            triggered_by_user_id: userId.uuidString,
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

    func handleVote(voteType: String) {
        // Toggle logic: if clicking the same vote, remove it
        if (voteType == "up" && upVoted) || (voteType == "down" && downVoted) {
            print("🔄 Removing \(voteType) vote (toggle off)")
            removeVote()
        } else {
            // Either switching votes or voting for first time
            print("✅ Submitting \(voteType) vote")
            submitPriceVote(voteType: voteType)
        }
    }

    func removeVote() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                try await SupabaseManager.shared.client
                    .from("price_votes")
                    .delete()
                    .eq("home_id", value: home.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                // Update local state
                await MainActor.run {
                    upVoted = false
                    downVoted = false
                }

                print("✅ Vote removed successfully")

                // Reload community price to see the effect
                loadCommunityPrice()
            } catch {
                print("❌ Error removing vote: \(error)")
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
                await MainActor.run {
                    if voteType == "up" {
                        upVoted = true
                        downVoted = false
                    } else {
                        downVoted = true
                        upVoted = false
                    }
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

    func loadUserVoteStatus() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct PriceVote: Decodable {
                    let voteType: String

                    enum CodingKeys: String, CodingKey {
                        case voteType = "vote_type"
                    }
                }

                let response: [PriceVote] = try await SupabaseManager.shared.client
                    .from("price_votes")
                    .select()
                    .eq("home_id", value: home.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                if let vote = response.first {
                    await MainActor.run {
                        if vote.voteType == "up" {
                            upVoted = true
                            downVoted = false
                        } else if vote.voteType == "down" {
                            downVoted = true
                            upVoted = false
                        }
                    }
                    print("📊 User vote status loaded: \(vote.voteType)")
                } else {
                    print("📊 User has not voted on this property")
                }
            } catch {
                print("❌ Error loading user vote status: \(error)")
            }
        }
    }

    func extractMentions(from text: String) -> [String] {
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let usernameRange = match.range(at: 1)
            return nsString.substring(with: usernameRange)
        }
    }

    func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    // MARK: - @Mention Autocomplete Functions

    func handleTextChange(oldValue: String, newValue: String) {
        // Detect if user is typing an @mention
        if newValue.contains("@") {
            // Find the last @ symbol
            if let atIndex = newValue.lastIndex(of: "@") {
                let afterAt = String(newValue[newValue.index(after: atIndex)...])

                // Check if there's a space or the string ends (valid mention in progress)
                if let spaceIndex = afterAt.firstIndex(of: " ") {
                    let query = String(afterAt[..<spaceIndex])
                    if !query.isEmpty {
                        mentionQuery = query
                        mentionStartIndex = atIndex
                        searchUsers(query: query)
                    } else {
                        showingSuggestions = false
                    }
                } else {
                    // Still typing the username
                    mentionQuery = afterAt
                    mentionStartIndex = atIndex
                    searchUsers(query: afterAt)
                }
            }
        } else {
            showingSuggestions = false
            suggestedUsers = []
            mentionQuery = ""
            mentionStartIndex = nil
        }
    }

    func searchUsers(query: String) {
        guard !query.isEmpty else {
            showingSuggestions = false
            suggestedUsers = []
            return
        }

        Task {
            do {
                let users: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .ilike("username", pattern: "%\(query)%")
                    .limit(5)
                    .execute()
                    .value

                await MainActor.run {
                    suggestedUsers = users
                    showingSuggestions = !users.isEmpty
                }
            } catch {
                print("Error searching users: \(error)")
                await MainActor.run {
                    suggestedUsers = []
                    showingSuggestions = false
                }
            }
        }
    }

    func selectUser(_ user: Profile) {
        guard let startIndex = mentionStartIndex else { return }

        // Replace @query with @username
        let beforeMention = String(newComment[..<startIndex])
        let afterMentionIndex = newComment.index(startIndex, offsetBy: mentionQuery.count + 1) // +1 for the @

        let afterMention: String
        if afterMentionIndex < newComment.endIndex {
            afterMention = String(newComment[afterMentionIndex...])
        } else {
            afterMention = ""
        }

        newComment = beforeMention + "@\(user.username) " + afterMention

        // Reset state
        showingSuggestions = false
        suggestedUsers = []
        mentionQuery = ""
        mentionStartIndex = nil
    }
}

struct CommentRow: View {
    let comment: Comment
    let currentUserId: UUID?
    let postOwnerId: UUID
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile photo with navigation
            NavigationLink(destination: {
                if let profile = comment.profile {
                    ProfileView(viewingUserId: profile.id)
                }
            }) {
                // Profile photo with initial fallback
                if let profile = comment.profile {
                    AvatarView(
                        avatarUrl: profile.avatarUrl,
                        username: profile.username,
                        size: 36
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
                        HStack(spacing: 4) {
                            Text("\(comment.profile?.username ?? "user")")
                                .fontWeight(.semibold)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            if comment.profile?.isVerified == true {
                                VerifiedBadge()
                            }
                        }
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

            // Delete button - show if current user is the comment owner OR post owner
            if let currentUserId = currentUserId,
               (currentUserId == comment.userId || currentUserId == postOwnerId) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
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

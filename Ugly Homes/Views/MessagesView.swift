//
//  MessagesView.swift
//  Ugly Homes
//
//  Messages Inbox View - List of all conversations
//

import SwiftUI

class UnreadMessagesManager: ObservableObject {
    @Published var totalUnreadCount: Int = 0
    private var pollingTask: Task<Void, Never>?

    func startPolling() {
        print("🔔 Starting unread messages polling")
        pollingTask?.cancel()

        pollingTask = Task {
            // Load immediately
            await loadUnreadCount()

            // Then poll every 5 seconds
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { break }
                    await loadUnreadCount()
                } catch {
                    if Task.isCancelled { break }
                }
            }
            print("🔕 Unread messages polling stopped")
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
    }

    func loadUnreadCount() async {
        do {
            let response: [ConversationPreview] = try await SupabaseManager.shared.client
                .from("conversation_previews")
                .select()
                .execute()
                .value

            let totalUnread = response.reduce(0) { $0 + $1.unreadCount }

            await MainActor.run {
                self.totalUnreadCount = totalUnread
                print("📬 Updated unread count: \(totalUnread)")
            }
        } catch {
            print("⚠️ Error loading unread count: \(error)")
        }
    }
}

struct SelectedUserInfo: Identifiable, Equatable {
    let id = UUID()
    let userId: UUID
    let username: String
    let avatarUrl: String?

    static func == (lhs: SelectedUserInfo, rhs: SelectedUserInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MessagesView: View {
    @EnvironmentObject var unreadManager: UnreadMessagesManager
    @State private var conversations: [ConversationPreview] = []
    @State private var isLoading = false
    @State private var selectedUserInfo: SelectedUserInfo?
    @State private var showNewMessage = false

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if conversations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "message")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No messages yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Start a conversation by visiting someone's profile")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            Button(action: {
                                print("🔵 Conversation tapped: \(conversation.otherUsername)")
                                selectedUserInfo = SelectedUserInfo(
                                    userId: conversation.otherUserId,
                                    username: conversation.otherUsername,
                                    avatarUrl: conversation.otherAvatarUrl
                                )
                                print("🔵 Set selectedUserInfo - username: \(conversation.otherUsername)")
                            }) {
                                ConversationRow(conversation: conversation)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showNewMessage = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                loadConversations()
            }
            .refreshable {
                loadConversations()
            }
            .sheet(item: $selectedUserInfo) { userInfo in
                let _ = print("🟢 Sheet presenting from list for: \(userInfo.username)")
                NavigationView {
                    ChatView(
                        otherUserId: userInfo.userId,
                        otherUsername: userInfo.username,
                        otherAvatarUrl: userInfo.avatarUrl
                    )
                }
            }
            .onChange(of: selectedUserInfo) { oldValue, newValue in
                // Reload conversations when chat is dismissed (unread count should update)
                if oldValue != nil && newValue == nil {
                    print("🔄 Chat dismissed, reloading conversations to update unread count")
                    // Add small delay to ensure database view is updated
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await MainActor.run {
                            loadConversations()
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView()
            }
            .onChange(of: showNewMessage) { oldValue, newValue in
                // Reload conversations when new message view is dismissed
                if oldValue && !newValue {
                    print("🔄 New message view dismissed, reloading conversations")
                    loadConversations()
                }
            }
        }
    }

    func loadConversations() {
        isLoading = true

        Task {
            do {
                print("📥 Loading conversations...")

                let response: [ConversationPreview] = try await SupabaseManager.shared.client
                    .from("conversation_previews")
                    .select()
                    .order("last_message_at", ascending: false)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) conversations")

                // Debug: Print unread counts
                for conv in response {
                    print("  📬 \(conv.otherUsername): \(conv.unreadCount) unread")
                }

                await MainActor.run {
                    conversations = response
                    isLoading = false
                }

                // Update unread count
                await unreadManager.loadUnreadCount()
            } catch {
                print("❌ Error loading conversations: \(error)")
                isLoading = false
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: ConversationPreview

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo with initial fallback
            AvatarView(
                avatarUrl: conversation.otherAvatarUrl,
                username: conversation.otherUsername,
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUsername)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    if let lastMessageTime = conversation.lastMessageTime {
                        Text(timeAgo(from: lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                HStack {
                    if let lastMessage = conversation.lastMessageContent {
                        Text(lastMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    } else {
                        Text("Start a conversation")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .italic()
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)

        if let week = components.weekOfYear, week > 0 {
            return "\(week)w"
        } else if let day = components.day, day > 0 {
            return "\(day)d"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m"
        } else {
            return "now"
        }
    }
}

// MARK: - New Message View
struct NewMessageView: View {
    @Environment(\.dismiss) var dismiss
    @State private var users: [Profile] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var selectedUserId: UUID?
    @State private var selectedUsername: String?
    @State private var selectedAvatarUrl: String?
    @State private var showChat = false

    var filteredUsers: [Profile] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.username.lowercased().contains(searchText.lowercased()) ||
                (user.fullName?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()

                Divider()

                if isLoading {
                    ProgressView()
                        .padding()
                } else if filteredUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "No users found" : "No results")
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredUsers) { user in
                            Button(action: {
                                print("🔵 User selected: \(user.username)")
                                selectedUserId = user.id
                                selectedUsername = user.username
                                selectedAvatarUrl = user.avatarUrl
                                print("🔵 Set user info - ID: \(user.id)")
                                showChat = true
                                print("🔵 showChat = \(showChat)")
                            }) {
                                HStack(spacing: 12) {
                                    // Profile photo
                                    if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            defaultAvatar
                                        }
                                    } else {
                                        defaultAvatar
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.username)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)

                                        if let fullName = user.fullName {
                                            Text(fullName)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUsers()
            }
            .sheet(isPresented: $showChat) {
                if let userId = selectedUserId, let username = selectedUsername {
                    let _ = print("🟢 Sheet presenting in NewMessageView for: \(username)")
                    NavigationView {
                        ChatView(
                            otherUserId: userId,
                            otherUsername: username,
                            otherAvatarUrl: selectedAvatarUrl
                        )
                    }
                    .onDisappear {
                        dismiss()
                    }
                } else {
                    let _ = print("🔴 selectedUserId or selectedUsername is nil in NewMessageView!")
                    Text("Error loading user")
                }
            }
        }
    }

    var defaultAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            )
    }

    func loadUsers() {
        isLoading = true

        Task {
            do {
                print("📥 Loading all users for new message...")

                // Get current user ID to exclude them from the list
                let currentUserId = try await SupabaseManager.shared.client.auth.session.user.id

                let response: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .neq("id", value: currentUserId.uuidString)
                    .order("username", ascending: true)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) users")
                users = response
                isLoading = false
            } catch {
                print("❌ Error loading users: \(error)")
                isLoading = false
            }
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(UnreadMessagesManager())
}

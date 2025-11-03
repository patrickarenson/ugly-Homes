//
//  MessagesView.swift
//  Ugly Homes
//
//  Messages Inbox View - List of all conversations
//

import SwiftUI

struct MessagesView: View {
    @State private var conversations: [ConversationPreview] = []
    @State private var isLoading = false
    @State private var selectedConversation: ConversationPreview?
    @State private var showChat = false
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
                                selectedConversation = conversation
                                showChat = true
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
            .sheet(isPresented: $showChat) {
                if let conversation = selectedConversation {
                    ChatView(
                        otherUserId: conversation.otherUserId,
                        otherUsername: conversation.otherUsername,
                        otherAvatarUrl: conversation.otherAvatarUrl
                    )
                }
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView()
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
                conversations = response
                isLoading = false
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
            // Profile photo
            if let avatarUrl = conversation.otherAvatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } placeholder: {
                    defaultAvatar
                }
            } else {
                defaultAvatar
            }

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

    var defaultAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            )
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
    @State private var selectedUser: Profile?
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
                                selectedUser = user
                                showChat = true
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
                if let user = selectedUser {
                    ChatView(
                        otherUserId: user.id,
                        otherUsername: user.username,
                        otherAvatarUrl: user.avatarUrl
                    )
                    .onDisappear {
                        dismiss()
                    }
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
}

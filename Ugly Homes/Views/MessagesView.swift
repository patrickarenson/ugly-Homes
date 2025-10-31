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

#Preview {
    MessagesView()
}

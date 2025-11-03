//
//  ChatView.swift
//  Ugly Homes
//
//  Individual Chat Conversation View
//

import SwiftUI

struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    let otherUserId: UUID
    let otherUsername: String
    let otherAvatarUrl: String?

    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var conversationId: UUID?
    @State private var currentUserId: UUID?
    @State private var isLoading = false
    @State private var isSending = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == currentUserId
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { oldCount, newCount in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Message input
                HStack(spacing: 12) {
                    TextField("Message...", text: $newMessage, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)

                    Button(action: sendMessage) {
                        if isSending {
                            ProgressView()
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(newMessage.isEmpty ? .gray : .orange)
                        }
                    }
                    .disabled(newMessage.isEmpty || isSending)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle(otherUsername)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadChat()
            }
        }
    }

    func loadChat() {
        isLoading = true

        Task {
            do {
                // Get current user ID
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                currentUserId = userId

                print("📥 Loading or creating conversation with \(otherUsername)...")

                // Get or create conversation
                struct ConversationIdResponse: Decodable {
                    let id: UUID
                }

                let response: ConversationIdResponse = try await SupabaseManager.shared.client
                    .rpc("get_or_create_conversation", params: ["other_user_id": otherUserId.uuidString])
                    .single()
                    .execute()
                    .value

                conversationId = response.id
                print("✅ Conversation ID: \(response.id)")

                // Load messages
                try await loadMessages()

                // Mark messages as read
                try await markMessagesAsRead()

                isLoading = false
            } catch {
                print("❌ Error loading chat: \(error)")
                isLoading = false
            }
        }
    }

    func loadMessages() async throws {
        guard let conversationId = conversationId else { return }

        print("📥 Loading messages for conversation \(conversationId)...")

        let response: [Message] = try await SupabaseManager.shared.client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        print("✅ Loaded \(response.count) messages")
        messages = response
    }

    func markMessagesAsRead() async throws {
        guard let conversationId = conversationId, let currentUserId = currentUserId else { return }

        // Mark all unread messages from other user as read
        try await SupabaseManager.shared.client
            .from("messages")
            .update(["is_read": true])
            .eq("conversation_id", value: conversationId.uuidString)
            .eq("is_read", value: false)
            .neq("sender_id", value: currentUserId.uuidString)
            .execute()
    }

    func sendMessage() {
        guard !newMessage.isEmpty,
              let conversationId = conversationId,
              let currentUserId = currentUserId else { return }

        let messageText = newMessage
        newMessage = ""
        isSending = true

        Task {
            do {
                print("📤 Sending message...")

                struct NewMessage: Encodable {
                    let conversation_id: String
                    let sender_id: String
                    let content: String
                }

                let newMsg = NewMessage(
                    conversation_id: conversationId.uuidString,
                    sender_id: currentUserId.uuidString,
                    content: messageText
                )

                let response: Message = try await SupabaseManager.shared.client
                    .from("messages")
                    .insert(newMsg)
                    .select()
                    .single()
                    .execute()
                    .value

                print("✅ Message sent")

                // Add to local messages
                messages.append(response)

                isSending = false
            } catch {
                print("❌ Error sending message: \(error)")
                newMessage = messageText // Restore message on error
                isSending = false
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Use MentionText for message content to make @mentions clickable
                MentionText(
                    text: message.content,
                    font: .body,
                    baseColor: isFromCurrentUser ? .white : .primary,
                    mentionColor: isFromCurrentUser ? .white.opacity(0.9) : .blue
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isFromCurrentUser ? Color.orange : Color(.systemGray5))
                .cornerRadius(16)

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: date)
    }
}

#Preview {
    ChatView(
        otherUserId: UUID(),
        otherUsername: "johndoe",
        otherAvatarUrl: nil
    )
}

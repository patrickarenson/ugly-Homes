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
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pollingTask: Task<Void, Never>?

    init(otherUserId: UUID, otherUsername: String, otherAvatarUrl: String?) {
        self.otherUserId = otherUserId
        self.otherUsername = otherUsername
        self.otherAvatarUrl = otherAvatarUrl
        print("🎬 ChatView initialized for \(otherUsername)")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading conversation...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        if messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No messages yet")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Send a message to start the conversation")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
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
                    }
                    .onChange(of: messages.count) { oldCount, newCount in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
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
            .onDisappear {
                pollingTask?.cancel()
            }
            .alert("Message Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
    }

    func loadChat() {
        isLoading = true

        Task {
            do {
                // Get current user ID
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                await MainActor.run {
                    currentUserId = userId
                }

                print("📥 Loading or creating conversation with \(otherUsername) (ID: \(otherUserId))...")
                print("📥 Current user ID: \(userId)")

                // Get or create conversation
                struct ConversationIdResponse: Decodable {
                    let id: UUID
                }

                let response: ConversationIdResponse = try await SupabaseManager.shared.client
                    .rpc("get_or_create_conversation", params: [
                        "current_user_id": userId.uuidString,
                        "other_user_id": otherUserId.uuidString
                    ])
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    conversationId = response.id
                }
                print("✅ Conversation ID: \(response.id)")

                // Load messages
                try await loadMessages()

                // Mark messages as read
                try await markMessagesAsRead()

                // Start polling for new messages
                startPollingForMessages()

                await MainActor.run {
                    isLoading = false
                }
            } catch {
                print("❌ Error loading chat: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
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

        await MainActor.run {
            messages = response
        }
    }

    func markMessagesAsRead() async throws {
        guard let conversationId = conversationId, let currentUserId = currentUserId else {
            print("⚠️ Cannot mark messages as read - missing conversationId or currentUserId")
            return
        }

        print("📖 Marking messages as read for conversation: \(conversationId.uuidString)")

        // Mark all unread messages from other user as read
        let response = try await SupabaseManager.shared.client
            .from("messages")
            .update(["is_read": true])
            .eq("conversation_id", value: conversationId.uuidString)
            .eq("is_read", value: false)
            .neq("sender_id", value: currentUserId.uuidString)
            .execute()

        print("✅ Messages marked as read - Response: \(response)")
    }

    func sendMessage() {
        guard !newMessage.isEmpty else {
            print("❌ Message is empty")
            return
        }

        guard let conversationId = conversationId else {
            print("❌ No conversation ID")
            return
        }

        guard let currentUserId = currentUserId else {
            print("❌ No current user ID")
            return
        }

        let messageText = newMessage
        newMessage = ""
        isSending = true

        Task {
            do {
                print("📤 Sending message to conversation: \(conversationId)")
                print("📤 Message content: \(messageText)")

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

                let response: [Message] = try await SupabaseManager.shared.client
                    .from("messages")
                    .insert(newMsg)
                    .select()
                    .execute()
                    .value

                print("✅ Message sent successfully! Inserted message ID: \(response.first?.id.uuidString ?? "unknown")")

                // Add the new message immediately (polling will keep it in sync)
                if let newMsg = response.first {
                    await MainActor.run {
                        messages.append(newMsg)
                        isSending = false
                    }
                } else {
                    await MainActor.run {
                        isSending = false
                    }
                }
            } catch {
                print("❌ Error sending message: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    newMessage = messageText // Restore message on error
                    isSending = false
                    errorMessage = "Failed to send message. Please try again."
                    showError = true
                }
            }
        }
    }

    func startPollingForMessages() {
        guard let conversationId = conversationId else {
            print("⚠️ Cannot start polling - missing conversationId")
            return
        }

        print("🔔 Starting message polling for conversation: \(conversationId)")

        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    // Wait 2 seconds between polls
                    try await Task.sleep(nanoseconds: 2_000_000_000)

                    guard !Task.isCancelled else { break }

                    // Load latest messages
                    let response: [Message] = try await SupabaseManager.shared.client
                        .from("messages")
                        .select()
                        .eq("conversation_id", value: conversationId.uuidString)
                        .order("created_at", ascending: true)
                        .execute()
                        .value

                    await MainActor.run {
                        let currentCount = messages.count
                        let newCount = response.count

                        // Only update if there are new messages
                        if newCount > currentCount {
                            print("📨 Found \(newCount - currentCount) new message(s)")
                            messages = response

                            // Mark new messages as read
                            Task {
                                try? await markMessagesAsRead()
                            }
                        }
                    }
                } catch {
                    if Task.isCancelled {
                        break
                    }
                    print("⚠️ Error polling for messages: \(error)")
                }
            }
            print("🔕 Message polling stopped")
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

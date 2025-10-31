//
//  Conversation.swift
//  Ugly Homes
//
//  Conversation Models
//

import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    let user1Id: UUID
    let user2Id: UUID
    let lastMessageAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
    }
}

struct ConversationPreview: Identifiable, Codable {
    let id: UUID
    let otherUserId: UUID
    let otherUsername: String
    let otherAvatarUrl: String?
    let lastMessageContent: String?
    let lastMessageTime: Date?
    let unreadCount: Int
    let lastMessageAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case otherUserId = "other_user_id"
        case otherUsername = "other_username"
        case otherAvatarUrl = "other_avatar_url"
        case lastMessageContent = "last_message_content"
        case lastMessageTime = "last_message_time"
        case unreadCount = "unread_count"
        case lastMessageAt = "last_message_at"
    }
}

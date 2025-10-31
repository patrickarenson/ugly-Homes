//
//  Message.swift
//  Ugly Homes
//
//  Message Model
//

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let content: String
    var isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

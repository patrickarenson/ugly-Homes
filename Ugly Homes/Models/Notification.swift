//
//  Notification.swift
//  Ugly Homes
//
//  In-app Notification Model
//

import Foundation

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let triggeredByUserId: UUID?
    let type: String
    let title: String
    let message: String
    let homeId: UUID?
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case triggeredByUserId = "triggered_by_user_id"
        case type
        case title
        case message
        case homeId = "home_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

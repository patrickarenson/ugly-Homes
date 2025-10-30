//
//  Comment.swift
//  Ugly Homes
//
//  Comment Model
//

import Foundation

struct Comment: Codable, Identifiable {
    let id: UUID
    let homeId: UUID
    let userId: UUID
    let commentText: String
    let createdAt: Date
    let updatedAt: Date

    // For display - user profile data (joined query)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case userId = "user_id"
        case commentText = "comment_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profile
    }
}

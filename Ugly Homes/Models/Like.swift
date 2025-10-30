//
//  Like.swift
//  Ugly Homes
//
//  Like Model
//

import Foundation

struct Like: Codable, Identifiable {
    let id: UUID
    let homeId: UUID
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

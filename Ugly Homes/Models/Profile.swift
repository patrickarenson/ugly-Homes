//
//  Profile.swift
//  Ugly Homes
//
//  User Profile Model
//

import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String
    var fullName: String?
    var avatarUrl: String?
    var bio: String?
    var market: String?
    var isVerified: Bool?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case bio
        case market
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

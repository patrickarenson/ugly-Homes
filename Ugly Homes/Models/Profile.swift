//
//  Profile.swift
//  Ugly Homes
//
//  User Profile Model
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let username: String
    var fullName: String?
    var avatarUrl: String?
    var bio: String?
    var market: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case bio
        case market
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

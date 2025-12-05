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
    var userTypes: [String]?
    var isVerified: Bool?
    var hasCompletedOnboarding: Bool?
    var followersCount: Int?
    var followingCount: Int?
    var points: Int?
    var tier: String?
    var streakDays: Int?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case bio
        case market
        case userTypes = "user_types"
        case isVerified = "is_verified"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case points
        case tier
        case streakDays = "streak_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

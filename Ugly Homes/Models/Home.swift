//
//  Home.swift
//  Ugly Homes
//
//  Home Listing Model
//

import Foundation

struct Home: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var listingType: String?
    var description: String?
    var price: Decimal?
    var address: String?
    var city: String?
    var state: String?
    var zipCode: String?
    var bedrooms: Int?
    var bathrooms: Decimal?
    var imageUrls: [String]
    var likesCount: Int
    var commentsCount: Int
    var viewCount: Int?
    var shareCount: Int?
    var saveCount: Int?
    var isActive: Bool
    var isArchived: Bool?
    var archivedAt: Date?
    var subscriptionId: String?
    var expiresAt: Date?
    let createdAt: Date
    let updatedAt: Date

    // For display - user profile data (joined query)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case listingType = "listing_type"
        case description
        case price
        case address
        case city
        case state
        case zipCode = "zip_code"
        case bedrooms
        case bathrooms
        case imageUrls = "image_urls"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case viewCount = "view_count"
        case shareCount = "share_count"
        case saveCount = "save_count"
        case isActive = "is_active"
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
        case subscriptionId = "subscription_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profile
    }
}

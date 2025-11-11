//
//  Home.swift
//  Ugly Homes
//
//  Home Listing Model
//

import Foundation

struct Home: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var title: String
    var listingType: String?
    var description: String?
    var price: Decimal?
    var address: String?
    var unit: String?
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
    var requiresReview: Bool?
    var moderationReason: String?
    var soldStatus: String?
    var soldDate: Date?
    var listingStatus: String? // active, pending, sold, off_market - auto-updated daily
    var zpid: String? // Zillow Property ID for status tracking
    var statusUpdatedAt: Date?
    var openHouseDate: Date?
    var openHouseEndDate: Date?
    var openHousePaid: Bool?
    var stripePaymentId: String?
    var subscriptionId: String?
    var expiresAt: Date?
    var tags: [String]?
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
        case unit
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
        case requiresReview = "requires_review"
        case moderationReason = "moderation_reason"
        case soldStatus = "sold_status"
        case soldDate = "sold_date"
        case listingStatus = "listing_status"
        case zpid
        case statusUpdatedAt = "status_updated_at"
        case openHouseDate = "open_house_date"
        case openHouseEndDate = "open_house_end_date"
        case openHousePaid = "open_house_paid"
        case stripePaymentId = "stripe_payment_id"
        case subscriptionId = "subscription_id"
        case expiresAt = "expires_at"
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profile
    }
}

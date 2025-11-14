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
    var listingStatus: String? // active, pending, sold, off_market - auto-updated with tiered frequency
    var zpid: String? // Zillow Property ID for status tracking
    var statusUpdatedAt: Date? // When the status last changed
    var statusCheckedAt: Date? // Last time we checked Zillow for updates (for tiered checking)
    var customDescription: Bool? // If true, prevents auto-updates from Zillow API
    var openHouseDate: Date?
    var openHouseEndDate: Date?
    var openHousePaid: Bool?
    var stripePaymentId: String?
    var subscriptionId: String?
    var expiresAt: Date?
    var tags: [String]?

    // Post type and project features
    var postType: String? // 'listing' or 'project'
    var beforePhotos: [String]? // Before photos for project posts (before/after feature)

    // Comprehensive property data (for future search features)
    var schoolDistrict: String?
    var elementarySchool: String?
    var middleSchool: String?
    var highSchool: String?
    var schoolRating: Decimal?
    var hoaFee: Decimal?
    var lotSizeSqft: Int?
    var livingAreaSqft: Int?
    var yearBuilt: Int?
    var propertyTypeDetail: String?
    var parkingSpaces: Int?
    var stories: Int?
    var heatingType: String?
    var coolingType: String?
    var appliancesIncluded: [String]?
    var additionalDetails: [String: AnyCodable]? // Flexible JSONB storage

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
        case statusCheckedAt = "status_checked_at"
        case customDescription = "custom_description"
        case openHouseDate = "open_house_date"
        case openHouseEndDate = "open_house_end_date"
        case openHousePaid = "open_house_paid"
        case stripePaymentId = "stripe_payment_id"
        case subscriptionId = "subscription_id"
        case expiresAt = "expires_at"
        case tags
        case postType = "post_type"
        case beforePhotos = "before_photos"
        case schoolDistrict = "school_district"
        case elementarySchool = "elementary_school"
        case middleSchool = "middle_school"
        case highSchool = "high_school"
        case schoolRating = "school_rating"
        case hoaFee = "hoa_fee"
        case lotSizeSqft = "lot_size_sqft"
        case livingAreaSqft = "living_area_sqft"
        case yearBuilt = "year_built"
        case propertyTypeDetail = "property_type_detail"
        case parkingSpaces = "parking_spaces"
        case stories
        case heatingType = "heating_type"
        case coolingType = "cooling_type"
        case appliancesIncluded = "appliances_included"
        case additionalDetails = "additional_details"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profile
    }
}

// Helper to decode flexible JSONB data
struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        return String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

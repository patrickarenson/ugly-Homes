//
//  TagKeywordMapper.swift
//  Ugly Homes
//
//  Maps user search terms to system tags for comprehensive searching
//

import Foundation

struct TagKeywordMapper {

    /// Map of tag names to their searchable keywords
    /// Allows users to search "fixer" and find properties tagged with #FixerUpper
    static let keywordMap: [String: [String]] = [
        // Buyer Persona Tags
        "Flippers": [
            "flip", "flipper", "flippers", "fix and flip", "fix & flip",
            "investor", "investment", "flip opportunity"
        ],

        "CashFlow": [
            "cash flow", "cashflow", "rental income", "income producing",
            "cap rate", "multifamily", "multi-family", "investment property",
            "roi", "return on investment", "buy and hold"
        ],

        "Vacation": [
            "vacation", "airbnb", "air bnb", "vrbo", "short term rental",
            "short-term rental", "vacation home", "vacation property",
            "vacation ready", "turnkey rental"
        ],

        "ForeverHome": [
            "forever home", "family home", "family friendly", "family-friendly",
            "spacious", "upgraded", "move in ready", "move-in ready"
        ],

        "Lifestyle": [
            "lifestyle", "active lifestyle", "outdoor", "trails", "hiking",
            "biking", "fitness", "near parks"
        ],

        "StarterHome": [
            "starter", "starter home", "first time buyer", "first-time buyer",
            "affordable", "entry level", "entry-level"
        ],

        "EscapeTheCity": [
            "escape", "escape the city", "rural", "retreat", "country",
            "secluded", "privacy", "peaceful", "quiet"
        ],

        // Property Condition Tags
        "FixerUpper": [
            "fixer", "fixer upper", "fixer-upper", "needs work", "tlc",
            "handyman special", "handyman", "cosmetic work", "renovation needed"
        ],

        "ValueAdd": [
            "value add", "value-add", "dated", "potential", "upside",
            "renovate", "update", "cosmetic updates"
        ],

        "GoodBones": [
            "good bones", "solid structure", "cosmetic", "cosmetic updates",
            "paint and carpet", "lipstick"
        ],

        "TurnKey": [
            "turn key", "turnkey", "renovated", "fully renovated", "gut renovated",
            "remodeled", "updated", "like new", "completely renovated"
        ],

        "NewBuild": [
            "new build", "new construction", "new", "brand new", "never lived in",
            "under construction", "builder"
        ],

        // Special Features
        "Pool": [
            "pool", "swimming pool", "heated pool", "saltwater pool",
            "resort style pool", "pool spa"
        ],

        "PetFriendly": [
            "pet", "pet friendly", "pet-friendly", "dog", "cat",
            "fenced yard", "fenced", "dog run"
        ],

        "Waterfront": [
            "waterfront", "water front", "lakefront", "lake front",
            "oceanfront", "ocean front", "beachfront", "beach front",
            "bayfront", "bay front", "dock", "boat dock", "boat slip"
        ],

        "Historic": [
            "historic", "historical", "heritage", "vintage", "classic",
            "restored", "character home", "period home", "old world"
        ],

        // Luxury & High-End
        "Luxury": [
            "luxury", "luxurious", "high end", "high-end", "upscale",
            "premium", "estate", "mansion", "exclusive", "prestige",
            "prestigious", "world class", "world-class"
        ],

        // Pricing/Value Tags
        "BelowMarket": [
            "below market", "below market value", "deal", "steal",
            "underpriced", "under priced", "priced to sell", "bargain"
        ],

        "MotivatedSeller": [
            "motivated", "motivated seller", "must sell", "quick sale",
            "price reduced", "reduced price", "bring offers", "all offers considered"
        ],

        // Distressed/Investor Tags
        "Foreclosure": [
            "foreclosure", "bank owned", "bank-owned", "reo",
            "real estate owned", "distressed"
        ],

        "ShortSale": [
            "short sale", "short-sale", "underwater", "upside down"
        ],

        "Auction": [
            "auction", "absolute auction", "estate sale", "probate",
            "estate auction", "bank auction"
        ],

        "PreForeclosure": [
            "pre-foreclosure", "preforeclosure", "pre foreclosure",
            "notice of default", "lis pendens"
        ]
    ]

    /// Search for properties by keyword - returns matching tag names
    /// Example: "fixer" returns ["FixerUpper"]
    static func findMatchingTags(for searchTerm: String) -> [String] {
        let cleanSearch = searchTerm.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard !cleanSearch.isEmpty else { return [] }

        var matchingTags: [String] = []

        // Check if the search term matches any keywords
        for (tagName, keywords) in keywordMap {
            // Check if search term matches tag name directly
            if tagName.lowercased() == cleanSearch {
                matchingTags.append(tagName)
                continue
            }

            // Check if search term matches any keyword
            for keyword in keywords {
                if keyword.lowercased().contains(cleanSearch) || cleanSearch.contains(keyword.lowercased()) {
                    matchingTags.append(tagName)
                    break // Only add tag once
                }
            }
        }

        return matchingTags
    }

    /// Get all searchable keywords for autocomplete suggestions
    static func getAllKeywords() -> [String] {
        var allKeywords = Set<String>()

        for (_, keywords) in keywordMap {
            for keyword in keywords {
                allKeywords.insert(keyword)
            }
        }

        // Also add the tag names themselves (without #)
        for tagName in keywordMap.keys {
            allKeywords.insert(tagName)
        }

        return Array(allKeywords).sorted()
    }
}

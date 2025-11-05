//
//  TagGenerator.swift
//  Ugly Homes
//
//  Auto-generate hashtags for property listings
//

import Foundation

struct TagGenerator {

    /// Generate hashtags for a property listing
    /// Returns array of tags like ["#Orlando", "#Under300K", "#Pool"]
    static func generateTags(
        city: String?,
        price: Decimal?,
        bedrooms: Int?,
        title: String,
        description: String?,
        listingType: String? = nil
    ) -> [String] {
        var tags: [String] = []

        // 1. City tag (always include if available)
        if let city = city, !city.isEmpty {
            let cleanCity = city
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "'", with: "")
            tags.append("#\(cleanCity)")
        }

        // 2. Listing Type tag - #ForLease for rentals, price tags for sales
        let isRental = listingType?.lowercased() == "rental" || listingType?.lowercased() == "lease"

        if isRental {
            // For rentals/leases, use #ForLease instead of price
            tags.append("#ForLease")
        } else if let price = price {
            // For sales, use price range tags
            let priceInt = Int(truncating: price as NSNumber)
            if priceInt < 100_000 {
                tags.append("#Under100K")
            } else if priceInt < 200_000 {
                tags.append("#Under200K")
            } else if priceInt < 300_000 {
                tags.append("#Under300K")
            } else if priceInt < 400_000 {
                tags.append("#Under400K")
            } else if priceInt < 500_000 {
                tags.append("#Under500K")
            } else if priceInt < 1_000_000 {
                tags.append("#Over500K")
            } else if priceInt < 5_000_000 {
                tags.append("#Over1M")
            } else if priceInt < 10_000_000 {
                tags.append("#Over5M")
            } else {
                tags.append("#Over10M")
            }
        }

        let text = "\(title) \(description ?? "")".lowercased()

        // 3. Waterfront (CRITICAL - major selling feature, comes before buyer personas)
        if text.contains("waterfront") ||
           text.contains("water front") ||
           text.contains("lakefront") ||
           text.contains("lake front") ||
           text.contains("oceanfront") ||
           text.contains("ocean front") ||
           text.contains("riverfront") ||
           text.contains("river front") ||
           text.contains("beachfront") ||
           text.contains("beach front") ||
           text.contains("dock") ||
           text.contains("private dock") ||
           text.contains("boat dock") ||
           text.contains("on the intercoastal") ||
           text.contains("on the intracoastal") ||
           text.contains("intercoastal") ||
           text.contains("intracoastal") ||
           text.contains("boat lift") ||
           text.contains("boat access") ||
           text.contains("deep water") {
            tags.append("#Waterfront")
        }

        // 4. Buyer Persona Tags (come after waterfront)

        // Flippers (fix & flip investors)
        if text.contains("fix and flip") ||
           text.contains("fix & flip") ||
           text.contains("flip opportunity") ||
           text.contains("diy") ||
           text.contains("do it yourself") {
            tags.append("#Flippers")
        }

        // Cash Flow Investors (buy & hold for rental income)
        // Exclude luxury price range ($2M+) - those aren't cashflow investments
        let isCashFlowPriceRange: Bool = {
            if let price = price {
                let priceInt = Int(truncating: price as NSNumber)
                return priceInt < 2_000_000
            }
            return true // If no price, allow CashFlow
        }()

        if isCashFlowPriceRange && (
           text.contains("rental income") ||
           text.contains("income producing") ||
           text.contains("cash flow") ||
           text.contains("high cap rate") ||
           text.contains("cap rate") ||
           text.contains("multifamily") ||
           text.contains("multi-family") ||
           text.contains("two-unit") ||
           text.contains("two unit") ||
           text.contains("as-is") ||
           text.contains("as is") ||
           text.contains("investment property") ||
           text.contains("investor special") ||
           text.contains("roi")) {
            tags.append("#CashFlow")
        }

        // Vacation / Airbnb Buyers (short-term rental properties)
        if text.contains("waterfront") ||
           text.contains("beachfront") ||
           text.contains("beach front") ||
           text.contains("mountain retreat") ||
           text.contains("vacation-ready") ||
           text.contains("vacation ready") ||
           text.contains("turnkey rental") ||
           text.contains("short-term rental") ||
           text.contains("short term rental") ||
           text.contains("airbnb") ||
           text.contains("air bnb") ||
           text.contains("vrbo") ||
           text.contains("resort-style amenities") ||
           text.contains("resort style amenities") ||
           text.contains("vacation home") ||
           text.contains("vacation property") {
            tags.append("#Vacation")
        }

        // Forever Home Buyers (upgraded family homes with space for growing families)
        // Exclude luxury price range ($2M+) - those are estates, not family homes
        let isForeverHomePriceRange: Bool = {
            if let price = price {
                let priceInt = Int(truncating: price as NSNumber)
                return priceInt < 2_000_000
            }
            return true // If no price, allow ForeverHome
        }()

        if isForeverHomePriceRange && (
           text.contains("spacious") ||
           text.contains("family-friendly") ||
           text.contains("family friendly") ||
           text.contains("open floor plan") ||
           text.contains("bonus room") ||
           text.contains("upgraded") ||
           text.contains("office") ||
           text.contains("home office") ||
           text.contains("backyard") ||
           text.contains("back yard") ||
           text.contains("garage") ||
           text.contains("family room") ||
           text.contains("patio") ||
           text.contains("walk-in closet") ||
           text.contains("walk in closet") ||
           text.contains("basement")) {
            tags.append("#ForeverHome")
        }

        // Lifestyle Buyers (active/outdoor lifestyle)
        if text.contains("trails") ||
           text.contains("walking trails") ||
           text.contains("near trails") ||
           text.contains("bike friendly") ||
           text.contains("bike path") ||
           text.contains("biking") ||
           text.contains("hiking") ||
           text.contains("mountain views") ||
           text.contains("mountains visible") ||
           text.contains("city & mountain views") ||
           text.contains("open space") ||
           text.contains("open green space") ||
           text.contains("parks nearby") ||
           text.contains("near parks") ||
           text.contains("near open space") ||
           text.contains("walk to open space") ||
           text.contains("outdoor living") ||
           text.contains("outdoor space") ||
           text.contains("deck") ||
           text.contains("fitness friendly") ||
           text.contains("active community") ||
           text.contains("golf course") ||
           text.contains("tennis") ||
           text.contains("swimming") {
            tags.append("#Lifestyle")
        }

        // Starter Home (consolidate all first-time buyer signals)
        // Exclude higher price range ($750K+) - those aren't starter homes
        let isStarterPriceRange: Bool = {
            if let price = price {
                let priceInt = Int(truncating: price as NSNumber)
                return priceInt < 750_000
            }
            return true // If no price, allow StarterHome
        }()

        if isStarterPriceRange && (
           text.contains("updated") ||
           text.contains("recently updated") ||
           text.contains("move-in ready") ||
           text.contains("move in ready") ||
           text.contains("affordable") ||
           text.contains("value") ||
           text.contains("priced to sell") ||
           text.contains("cozy") ||
           text.contains("single-family") ||
           text.contains("single family") ||
           text.contains("close to schools") ||
           text.contains("good school") ||
           text.contains("school district") ||
           text.contains("great location") ||
           text.contains("neighborhood") ||
           text.contains("open floor plan") ||
           text.contains("low maintenance") ||
           text.contains("easy care") ||
           text.contains("walkable") ||
           text.contains("near shopping") ||
           text.contains("near amenities")) {
            tags.append("#StarterHome")
        }

        // Pet Friendly / Dog Friendly (consolidate all variations)
        if text.contains("dog-friendly") ||
           text.contains("dog friendly") ||
           text.contains("pet-friendly") ||
           text.contains("pet friendly") ||
           text.contains("fenced backyard") ||
           text.contains("fully fenced yard") ||
           text.contains("large yard") && text.contains("pets") ||
           text.contains("room to roam") ||
           text.contains("pet lovers") ||
           text.contains("private yard") && text.contains("pets") ||
           text.contains("dog park") ||
           text.contains("walking trails") ||
           text.contains("hoa allows pets") ||
           text.contains("pet-friendly community") ||
           text.contains("pets allowed") {
            tags.append("#PetFriendly")
        }

        // Luxury Properties (buyer persona - consolidate all variations)
        // Also detect by price: $10M+ is automatically luxury
        let isLuxuryPrice: Bool = {
            if let price = price {
                return Int(truncating: price as NSNumber) >= 10_000_000
            }
            return false
        }()

        if isLuxuryPrice ||
           text.contains("custom-built") ||
           text.contains("custom built") ||
           text.contains("custom-designed") ||
           text.contains("custom designed") ||
           text.contains("luxury") ||
           text.contains("luxurious") ||
           text.contains("impeccable") ||
           text.contains("pristine") ||
           text.contains("estate") ||
           text.contains("manor") ||
           text.contains("residence") && (text.contains("luxury") || text.contains("custom")) ||
           text.contains("gourmet kitchen") ||
           text.contains("chef's kitchen") ||
           text.contains("chefs kitchen") ||
           text.contains("resort-style") ||
           text.contains("resort style") ||
           text.contains("resort-living") ||
           text.contains("resort living") ||
           text.contains("panoramic views") ||
           text.contains("breathtaking views") ||
           text.contains("gated community") ||
           text.contains("designer finishes") ||
           text.contains("high-end finishes") ||
           text.contains("high end finishes") ||
           text.contains("spa-like") ||
           text.contains("home-spa") ||
           text.contains("home spa") ||
           text.contains("indoor-outdoor living") ||
           text.contains("indoor outdoor living") ||
           text.contains("seamless indoor") ||
           text.contains("smart home") ||
           text.contains("state-of-the-art") ||
           text.contains("infinity pool") ||
           text.contains("outdoor kitchen") ||
           text.contains("vaulted ceilings") ||
           text.contains("great room") ||
           text.contains("wine cellar") ||
           text.contains("home theater") ||
           text.contains("home gym") ||
           text.contains("grandest") ||
           text.contains("palatial") ||
           text.contains("meticulously") ||
           text.contains("dazzling") ||
           text.contains("towering") ||
           text.contains("once-in-a-lifetime") ||
           text.contains("once in a lifetime") ||
           text.contains("private elevator") ||
           text.contains("private terrace") ||
           text.contains("doorman") ||
           text.contains("library") {
            tags.append("#Luxury")
        }

        // New Construction / Modern Homes (buyer persona)
        if text.contains("new construction") ||
           text.contains("newly built") ||
           text.contains("recently built") ||
           text.contains("brand new") ||
           text.contains("2024") ||
           text.contains("2025") ||
           text.contains("smart home") ||
           text.contains("smart-home") ||
           text.contains("energy-efficient") ||
           text.contains("energy efficient") ||
           text.contains("high-efficiency") ||
           text.contains("high efficiency") ||
           text.contains("green build") ||
           text.contains("open-concept") ||
           text.contains("open concept") ||
           text.contains("large windows") ||
           text.contains("natural light") ||
           text.contains("high-end appliances") ||
           text.contains("high end appliances") ||
           text.contains("professional-grade appliances") ||
           text.contains("professional grade appliances") ||
           text.contains("quartz countertops") ||
           text.contains("quartzite") ||
           text.contains("minimalist") ||
           text.contains("contemporary") ||
           text.contains("modern design") ||
           text.contains("modern luxury") ||
           text.contains("expression of modern") ||
           text.contains("infinity-edge") ||
           text.contains("infinity edge") ||
           text.contains("lock-and-leave") ||
           text.contains("lock and leave") ||
           text.contains("turn-key") ||
           text.contains("turnkey") ||
           text.contains("builder warranty") ||
           text.contains("under construction") ||
           text.contains("spec home") ||
           text.contains("lutron") ||
           text.contains("sonos") {
            tags.append("#NewConstruction")
        }

        // Escape The City (rural/farm properties for city escapees)
        if text.contains("farmhouse") ||
           text.contains("ranch-style") ||
           text.contains("ranch style") ||
           text.contains("rustic charm") ||
           text.contains("updated farmhouse") ||
           text.contains("modern country home") ||
           text.contains("wraparound porch") ||
           text.contains("classic country kitchen") ||
           text.contains("country kitchen") ||
           text.contains("private retreat") ||
           text.contains("secluded") ||
           text.contains("tranquil setting") ||
           text.contains("peaceful countryside") ||
           text.contains("country living") ||
           text.contains("mountain views") ||
           text.contains("creek") ||
           text.contains("pond") && text.contains("property") ||
           text.contains("lake on property") ||
           text.contains("homestead-ready") ||
           text.contains("homestead ready") ||
           text.contains("self-sufficient living") ||
           text.contains("self sufficient living") ||
           text.contains("off-grid potential") ||
           text.contains("off grid potential") ||
           text.contains("off-grid") ||
           text.contains("off grid") ||
           text.contains("solar panels") ||
           text.contains("well") && text.contains("septic") ||
           text.contains("fresh air") ||
           text.contains("escape the city") ||
           text.contains("rural charm") ||
           text.contains("acreage") ||
           text.contains("acre lot") ||
           text.contains("acres") ||
           text.contains("sprawling property") ||
           text.contains("open land") ||
           text.contains("rolling hills") ||
           text.contains("wide open views") ||
           text.contains("room for horses") ||
           text.contains("equestrian property") ||
           text.contains("equestrian") ||
           text.contains("barn included") ||
           text.contains("barn") ||
           text.contains("pasture") ||
           text.contains("fenced acreage") ||
           text.contains("garden space") ||
           text.contains("workshop") ||
           text.contains("rv parking") ||
           text.contains("detached garage") {
            tags.append("#EscapeTheCity")
        }

        // Historic Homes (buyers seeking historic properties with character)
        // Note: Only tag as historic if it's an ACTUAL historic building, not modern with historic-inspired style
        if text.contains("historic home") ||
           text.contains("historic district") ||
           text.contains("registered historic") ||
           text.contains("historic property") ||
           text.contains("built in 18") ||
           text.contains("built in 19") ||
           text.contains("turn-of-the-century home") ||
           text.contains("turn of the century home") ||
           text.contains("circa 18") ||
           text.contains("circa 19") ||
           text.contains("preserved architecture") ||
           text.contains("period details") ||
           text.contains("original character") ||
           text.contains("original hardwood") ||
           text.contains("original molding") ||
           text.contains("original windows") ||
           text.contains("original trim") ||
           text.contains("historic charm") ||
           text.contains("historic features") ||
           text.contains("restored historic") {
            tags.append("#Historic")
        }

        // 5. Feature Tags (supplementary features)

        // Pool (try to detect private pools, not community pools)
        if text.contains("pool") && !text.contains("community pool") {
            tags.append("#Pool")
        }

        // Fixer Upper / Needs Work (shared investor tag)
        if text.contains("fixer") ||
           text.contains("fixer-upper") ||
           text.contains("fixer upper") ||
           text.contains("needs work") ||
           text.contains("needs tlc") ||
           text.contains("needs updating") ||
           text.contains("tlc") ||
           text.contains("handyman") ||
           text.contains("cosmetic update") ||
           text.contains("bring your tools") ||
           text.contains("sweat equity") ||
           text.contains("vintage") {
            tags.append("#FixerUpper")
        }

        // Value Add (shared investor tag)
        if text.contains("value-add") ||
           text.contains("value add") ||
           text.contains("opportunity to customize") ||
           text.contains("customize") ||
           text.contains("add value") {
            tags.append("#ValueAdd")
        }

        // Good Bones (shared investor tag)
        if text.contains("good bones") ||
           text.contains("great bones") ||
           text.contains("solid bones") {
            tags.append("#GoodBones")
        }

        // Below Market (shared investor tag)
        if text.contains("under market") ||
           text.contains("below market") ||
           text.contains("priced to sell") ||
           text.contains("motivated seller") ||
           text.contains("must sell") ||
           text.contains("reduced") {
            tags.append("#BelowMarket")
        }

        // Potential (shared investor tag)
        if text.contains("major potential") ||
           text.contains("huge potential") ||
           text.contains("lots of potential") ||
           text.contains("great potential") {
            tags.append("#Potential")
        }

        // Renovation/Remodel
        if text.contains("renovat") ||
           text.contains("remodel") ||
           text.contains("updat") ||
           text.contains("modern") {
            tags.append("#Renovation")
        }

        // 6. Size tags (based on bedrooms)
        if let bedrooms = bedrooms {
            if bedrooms >= 4 {
                tags.append("#LargeProperty")
            } else if bedrooms <= 1 {
                tags.append("#Studio")
            }
        }

        // Limit to top 5 most relevant tags
        return Array(tags.prefix(5))
    }
}

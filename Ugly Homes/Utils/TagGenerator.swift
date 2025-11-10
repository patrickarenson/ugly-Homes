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
        // IMPORTANT: Exclude properties with only "views" - views are NOT waterfront
        let hasWaterViews = text.contains("water views") ||
                           text.contains("lake views") ||
                           text.contains("lakefront views") ||
                           text.contains("ocean views") ||
                           text.contains("oceanfront views") ||
                           text.contains("river views") ||
                           text.contains("bay views") ||
                           text.contains("views of the water") ||
                           text.contains("views of the lake") ||
                           text.contains("views of the ocean") ||
                           text.contains("views across") ||
                           text.contains("overlooking")

        let hasActualWaterfront = text.contains("waterfront") ||
           text.contains("water front") ||
           text.contains("lakefront") ||
           text.contains("lake front") ||
           text.contains("oceanfront") ||
           text.contains("ocean front") ||
           text.contains("riverfront") ||
           text.contains("river front") ||
           text.contains("beachfront") ||
           text.contains("beach front") ||
           text.contains("bayfront") ||
           text.contains("bay front") ||
           text.contains("bay frontage") ||
           text.contains("dock") ||
           text.contains("private dock") ||
           text.contains("boat dock") ||
           text.contains("slip") ||
           text.contains("boat slip") ||
           text.contains("boathouse") ||
           text.contains("boat house") ||
           text.contains("on the intercoastal") ||
           text.contains("on the intracoastal") ||
           text.contains("intercoastal") ||
           text.contains("intracoastal") ||
           text.contains("boat lift") ||
           text.contains("boat access") ||
           text.contains("deep water") ||
           text.contains("direct water access") ||
           text.contains("direct bay access") ||
           text.contains("direct ocean access") ||
           text.contains("direct lake access") ||
           text.contains("water access")

        // Only tag as waterfront if it has actual water access AND not just views
        if hasActualWaterfront && !hasWaterViews {
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
        // Exclude luxury residential price range ($2M+) - those aren't typical cashflow investments
        // BUT include commercial/mixed-use at any price (hotels, multifamily, etc.)
        let isCashFlowPriceRange: Bool = {
            if let price = price {
                let priceInt = Int(truncating: price as NSNumber)
                return priceInt < 2_000_000
            }
            return true // If no price, allow CashFlow
        }()

        // Commercial opportunities qualify at any price
        let isCommercialOpportunity =
           text.contains("commercial potential") ||
           text.contains("commercial zoning") ||
           text.contains("mixed-use") ||
           text.contains("mixed use") ||
           text.contains("hotel potential") ||
           text.contains("boutique hotel") ||
           text.contains("motel") ||
           text.contains("transient lodging") ||
           text.contains("permitted uses") ||
           text.contains("zoning allows") ||
           text.contains("development rights") ||
           text.contains("hct zone") ||
           text.contains("commercial district") ||
           text.contains("tourist district")

        if (isCashFlowPriceRange || isCommercialOpportunity) && (
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
           text.contains("roi") ||
           text.contains("under renovation") ||
           text.contains("under construction") ||
           text.contains("completion in") ||
           text.contains("expected completion") ||
           text.contains("renovation") && text.contains("months") ||
           text.contains("construction") && text.contains("timeline") ||
           isCommercialOpportunity) {
            tags.append("#CashFlow")
        }

        // Vacation / Airbnb Buyers (short-term rental properties)
        // Include waterfront AND water views properties
        // IMPORTANT: Exclude high-end luxury estates ($10M+) OR estates with luxury indicators

        // Detect luxury estate features (library, theater, spa, etc.)
        let hasLuxuryEstateFeatures = text.contains("library") ||
           text.contains("home theater") ||
           text.contains("theater room") ||
           text.contains("media room") ||
           text.contains("bar") && (text.contains("wet bar") || text.contains("wine") || text.contains("gourmet")) ||
           text.contains("spa") && text.contains("sauna") ||
           text.contains("sauna") ||
           text.contains("steam room") ||
           text.contains("wine cellar") ||
           text.contains("wine room") ||
           text.contains("elevator") ||
           text.contains("private elevator") ||
           text.contains("staff quarters") ||
           text.contains("maid's quarters") ||
           text.contains("guest house") && text.contains("estate") ||
           text.contains("prestigious") ||
           text.contains("palatial") ||
           text.contains("sprawling estate") ||
           text.contains("compound")

        let isVacationPriceRange: Bool = {
            if let price = price {
                let priceInt = Int(truncating: price as NSNumber)
                return priceInt < 10_000_000
            }
            // If no price, check for luxury estate features
            return !hasLuxuryEstateFeatures
        }()

        // Explicit vacation indicators (these work at any price)
        let hasExplicitVacationIndicators = text.contains("vacation-ready") ||
           text.contains("vacation ready") ||
           text.contains("turnkey rental") ||
           text.contains("short-term rental") ||
           text.contains("short term rental") ||
           text.contains("airbnb") ||
           text.contains("air bnb") ||
           text.contains("vrbo") ||
           text.contains("vacation home") ||
           text.contains("vacation property")

        // Location-based vacation appeal (only for mid-range properties without luxury estate features)
        let hasLocationVacationAppeal = hasActualWaterfront ||
           hasWaterViews ||
           text.contains("mountain retreat") ||
           text.contains("resort-style amenities") ||
           text.contains("resort style amenities")

        if hasExplicitVacationIndicators ||
           (isVacationPriceRange && hasLocationVacationAppeal) {
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
        // IMPORTANT: Only tag properties where active lifestyle is the PRIMARY appeal
        // Exclude luxury estates ($10M+ or with luxury estate features) - they're already tagged as luxury
        // Generic "outdoor spaces" are NOT lifestyle - need actual trails, fitness, sports
        let isLifestylePriceRange: Bool = {
            if let price = price {
                let priceInt = Int(truncating: price as NSNumber)
                return priceInt < 10_000_000
            }
            // If no price, check for luxury estate features
            return !hasLuxuryEstateFeatures
        }()

        if isLifestylePriceRange && (
           text.contains("trails") ||
           text.contains("walking trails") ||
           text.contains("near trails") ||
           text.contains("bike friendly") ||
           text.contains("bike path") ||
           text.contains("biking") ||
           text.contains("hiking") ||
           text.contains("mountain views") ||
           text.contains("mountains visible") ||
           text.contains("city & mountain views") ||
           text.contains("open green space") ||
           text.contains("parks nearby") ||
           text.contains("near parks") ||
           text.contains("near open space") ||
           text.contains("walk to open space") ||
           text.contains("fitness friendly") ||
           text.contains("active community") ||
           text.contains("golf course") ||
           text.contains("tennis court") ||
           text.contains("tennis") ||
           text.contains("lap pool") ||
           text.contains("fitness center") ||
           text.contains("gym access") ||
           text.contains("yoga studio") ||
           text.contains("basketball court") ||
           text.contains("pickleball") ||
           text.contains("sports court")) {
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
        // INCLUDES: luxury brands, high-end materials, designer names
        let isLuxuryPrice: Bool = {
            if let price = price {
                return Int(truncating: price as NSNumber) >= 10_000_000
            }
            return false
        }()

        // Luxury brands and materials
        let hasLuxuryBrands = text.contains("miele") ||
                             text.contains("sub-zero") ||
                             text.contains("subzero") ||
                             text.contains("wolf") ||
                             text.contains("thermador") ||
                             text.contains("la cornue") ||
                             text.contains("gaggenau") ||
                             text.contains("kallista") ||
                             text.contains("dornbracht") ||
                             text.contains("waterworks") ||
                             text.contains("lefroy brooks") ||
                             text.contains("duravit") ||
                             text.contains("toto neorest") ||
                             text.contains("visual comfort") ||
                             text.contains("calacatta") ||
                             text.contains("statuario") ||
                             text.contains("noir st. laurent") ||
                             text.contains("nero marquina") ||
                             text.contains("brudnizki") ||
                             text.contains("kelly wearstler") ||
                             text.contains("peter marino")

        if isLuxuryPrice ||
           hasLuxuryBrands ||
           text.contains("custom-built") ||
           text.contains("custom built") ||
           text.contains("custom-designed") ||
           text.contains("custom designed") ||
           text.contains("luxury") ||
           text.contains("luxurious") ||
           text.contains("lavish") ||
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
           text.contains("bespoke") ||
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
           text.contains("library") ||
           text.contains("penthouse") {
            tags.append("#Luxury")
        }

        // New Build (buyer persona - only for brand new construction)
        // IMPORTANT: Only tag properties that are literally brand new or under construction
        // NOT renovated homes, conversions, or historic transformations
        let isConversion = text.contains("conversion") ||
                          text.contains("adaptive reuse") ||
                          text.contains("historic conversion") ||
                          text.contains("originally built") ||
                          text.contains("originally designed") ||
                          text.contains("transformation") ||
                          text.contains("reimagined") ||
                          text.contains("reborn")

        if !isConversion && (
           text.contains("new construction") ||
           text.contains("newly built") ||
           text.contains("recently built") ||
           text.contains("brand new home") ||
           text.contains("brand new construction") ||
           text.contains("built in 2024") ||
           text.contains("built in 2025") ||
           text.contains("built in 2026") ||
           text.contains("2024 construction") ||
           text.contains("2025 construction") ||
           text.contains("2026 construction") ||
           text.contains("builder warranty") ||
           text.contains("builder's warranty") ||
           text.contains("under construction") ||
           text.contains("spec home") ||
           text.contains("spec house") ||
           text.contains("to be built") ||
           text.contains("pre-construction") ||
           text.contains("never lived in") ||
           text.contains("never occupied") ) {
            tags.append("#NewBuild")
        }

        // TurnKey (fully renovated homes OR new builds - move-in ready)
        // For homes that need zero work, either because they're new or completely renovated
        // Includes historic conversions and transformations
        if text.contains("turnkey") ||
           text.contains("turn-key") ||
           text.contains("turn key") ||
           text.contains("fully renovated") ||
           text.contains("completely renovated") ||
           text.contains("total renovation") ||
           text.contains("gut renovation") ||
           text.contains("gut rehab") ||
           text.contains("gutted") ||
           text.contains("down to the studs") ||
           text.contains("new everything") ||
           text.contains("everything is new") ||
           text.contains("top to bottom renovation") ||
           text.contains("move-in ready") ||
           text.contains("move in ready") ||
           text.contains("nothing to do") ||
           text.contains("ready to move in") ||
           text.contains("completely updated") ||
           text.contains("fully updated") ||
           text.contains("like new condition") ||
           text.contains("extensive transformation") ||
           text.contains("extensive renovation") ||
           text.contains("reimagined") ||
           text.contains("reborn") ||
           text.contains("conversion") && (text.contains("residential") || text.contains("condos") || text.contains("apartments")) ||
           text.contains("adaptive reuse") ||
           text.contains("historic conversion") {
            tags.append("#TurnKey")
        }

        // Escape The City (rural/farm properties for city escapees)
        // IMPORTANT: Only for actual rural/farm properties, not luxury urban/suburban estates with acreage
        // Exclude luxury estates - they're not "escape the city", they're gated luxury compounds
        let isEscapeTheCity = !hasLuxuryEstateFeatures && (
           text.contains("farmhouse") ||
           text.contains("ranch-style") ||
           text.contains("ranch style") ||
           text.contains("rustic charm") ||
           text.contains("updated farmhouse") ||
           text.contains("modern country home") ||
           text.contains("wraparound porch") ||
           text.contains("classic country kitchen") ||
           text.contains("country kitchen") ||
           text.contains("peaceful countryside") ||
           text.contains("country living") ||
           text.contains("creek on property") ||
           text.contains("natural pond") ||
           text.contains("stock pond") ||
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
           text.contains("escape the city") ||
           text.contains("rural charm") ||
           text.contains("rural property") ||
           text.contains("acreage") && !text.contains("estate") ||
           text.contains("acre lot") && text.contains("acres") && !text.contains("estate") ||
           text.contains("sprawling property") && text.contains("acres") && !text.contains("luxury") ||
           text.contains("open land") ||
           text.contains("rolling hills") ||
           text.contains("wide open views") && text.contains("acres") ||
           text.contains("room for horses") ||
           text.contains("equestrian property") ||
           text.contains("equestrian") ||
           text.contains("barn included") ||
           text.contains("barn") && text.contains("acres") ||
           text.contains("pasture") ||
           text.contains("fenced acreage") ||
           text.contains("garden space") && text.contains("acres") ||
           text.contains("rv parking") && text.contains("acres"))

        if isEscapeTheCity {
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
        // Includes development opportunities and blank canvas properties
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
           text.contains("vintage") ||
           text.contains("undeveloped") ||
           text.contains("undeveloped property") ||
           text.contains("blank canvas") ||
           text.contains("development opportunity") ||
           text.contains("ground-up") ||
           text.contains("ground up") ||
           text.contains("tear down") ||
           text.contains("teardown") ||
           text.contains("build new") ||
           text.contains("rebuild") ||
           text.contains("redevelopment") ||
           text.contains("transform") ||
           text.contains("transformation") ||
           text.contains("creative vision") ||
           text.contains("bring your vision") ||
           text.contains("shaping a new vision") ||
           text.contains("rare opportunity") ||
           text.contains("unique opportunity") ||
           text.contains("once-in-lifetime") ||
           text.contains("once in a lifetime") ||
           text.contains("one of a kind") && (text.contains("opportunity") || text.contains("potential")) ||
           text.contains("final chance") {
            tags.append("#FixerUpper")
        }

        // Value Add (properties with opportunity to increase value)
        // Includes: dated luxury, development opportunities, customization potential

        // Detect dated technology/systems (older luxury indicators)
        let hasDatedLuxury = text.contains("viking") && text.contains("appliances") ||
                            text.contains("crestron") && !text.contains("new") && !text.contains("updated") ||
                            text.contains("timeless elegance") && !text.contains("renovated") && !text.contains("updated")

        // Detect emphasis on bones/architecture over finishes
        let emphasizesBones = (text.contains("designed by") || text.contains("architect")) &&
                             (text.contains("opportunity") || text.contains("potential")) ||
                             text.contains("great bones") ||
                             text.contains("good bones") ||
                             text.contains("solid bones")

        if text.contains("value-add") ||
           text.contains("value add") ||
           text.contains("opportunity to customize") ||
           text.contains("customize to your taste") ||
           text.contains("add value") ||
           text.contains("bring your vision") ||
           text.contains("make it your own") ||
           text.contains("personalize") ||
           text.contains("blank canvas") && (text.contains("luxury") || text.contains("estate")) ||
           text.contains("development opportunity") ||
           text.contains("redevelopment") ||
           text.contains("update to your standards") ||
           hasDatedLuxury ||
           emphasizesBones {
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

        // Motivated Seller (deal-seeker tag - seller urgency/flexibility)
        if text.contains("bring all offers") ||
           text.contains("all offers") ||
           text.contains("motivated seller") ||
           text.contains("must sell") ||
           text.contains("owner financing") ||
           text.contains("flexible terms") ||
           text.contains("price reduction") ||
           text.contains("price reduced") ||
           text.contains("recently reduced") ||
           text.contains("just reduced") ||
           text.contains("make an offer") ||
           text.contains("open to offers") ||
           text.contains("accepting offers") {
            tags.append("#MotivatedSeller")
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

        // Limit to top 7 most relevant tags (increased to ensure feature tags like Pool aren't cut off)
        return Array(tags.prefix(7))
    }
}

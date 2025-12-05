//
//  PriceFeedView.swift
//  Ugly Homes
//
//  Feed sorted by price with filters
//

import SwiftUI
import CoreLocation

struct PriceFeedView: View {
    @State private var homes: [Home] = []
    @State private var allHomes: [Home] = []
    @State private var allCities: [String] = []  // All cities from database
    @State private var isLoading = true
    @State private var isSearchingCity = false  // Loading state for city search
    @State private var listingFilter: ListingFilter = .all
    @State private var tagSearch = ""
    @State private var selectedTags: [String] = []
    @State private var showTagSuggestions = false
    @State private var showSearchPanel = false
    @State private var minPrice: Double = 25000
    @State private var maxPrice: Double = 50000000
    @State private var selectedCity: String = ""
    @State private var selectedBedrooms: Int? = nil
    @State private var selectedBathrooms: Int? = nil
    @State private var showCitySuggestions = false
    @State private var userCurrentCity: String = ""  // Auto-detected city
    @StateObject private var cityLocationManager = CityLocationManager()
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isTagFieldFocused: Bool
    @FocusState private var isCityFieldFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var pendingScrollTarget: UUID? = nil  // Store pending scroll target for map return

    // Get all unique tags from homes for autocomplete
    var availableTags: [String] {
        var tags: Set<String> = []
        for home in allHomes {
            if let homeTags = home.tags {
                for tag in homeTags {
                    tags.insert(tag)
                }
            }
        }
        return Array(tags).sorted()
    }

    // Get all unique cities - use pre-fetched list from database
    var availableCities: [String] {
        return allCities
    }

    // Get all searchable keywords for autocomplete
    var searchableKeywords: [String] {
        // Combine actual tags from properties + all keyword mappings + cities
        var keywords = Set<String>()

        // Add all actual tags (without #)
        for tag in availableTags {
            keywords.insert(tag.replacingOccurrences(of: "#", with: ""))
        }

        // Add all cities
        for city in availableCities {
            keywords.insert(city)
        }

        // Add all keyword mappings
        for keywordArray in TagKeywordMapper.keywordMap.values {
            for keyword in keywordArray {
                keywords.insert(keyword)
            }
        }

        return Array(keywords).sorted()
    }

    // Filter tags/keywords based on search
    var suggestedTags: [String] {
        guard !tagSearch.isEmpty else { return [] }
        let search = tagSearch.lowercased().replacingOccurrences(of: "#", with: "")

        // Search in all keywords
        let matchingKeywords = searchableKeywords.filter { keyword in
            keyword.lowercased().contains(search) && !selectedTags.contains(keyword)
        }

        return Array(matchingKeywords.prefix(5))
    }

    // Filter cities based on search for autocomplete
    var suggestedCities: [String] {
        guard !selectedCity.isEmpty else { return [] }
        let search = selectedCity.lowercased()

        let matchingCities = allCities.filter { city in
            city.lowercased().contains(search) || city.lowercased().hasPrefix(search)
        }

        // Sort by prefix match first, then alphabetically
        let sorted = matchingCities.sorted { city1, city2 in
            let prefix1 = city1.lowercased().hasPrefix(search)
            let prefix2 = city2.lowercased().hasPrefix(search)
            if prefix1 && !prefix2 { return true }
            if !prefix1 && prefix2 { return false }
            return city1 < city2
        }

        return Array(sorted.prefix(5))
    }

    enum ListingFilter: String, CaseIterable {
        case all = "All"
        case rentals = "Rentals"
        case sales = "Sales"
    }

    var filteredHomes: [Home] {
        var filtered = homes

        // Debug: Only log when something significant happens
        if homes.count > 0 || !selectedCity.isEmpty {
            print("🔎 filteredHomes: \(homes.count) homes, city='\(selectedCity)'")
        }

        // Filter by price range - use >= and <= for inclusive bounds
        // Note: When maxPrice is at maximum ($50M), skip the upper bound check entirely
        // Note: Only apply price filter if user has adjusted it from defaults, OR if listing type filter matches
        let skipMaxPriceFilter = maxPrice >= 49500000
        let priceFilterIsDefault = minPrice <= 25000 && maxPrice >= 49500000

        // If price filter is at default AND listing filter is "All", skip price filtering entirely
        // This allows rentals (which have lower monthly prices) to show alongside sales
        let skipPriceFilter = priceFilterIsDefault && listingFilter == .all

        filtered = filtered.filter { home in
            guard let price = home.price else { return false }

            // Skip price filter for rentals if using default price range
            // Rentals have monthly prices ($1k-$10k), sales have purchase prices ($100k+)
            if skipPriceFilter {
                return true
            }

            // For rentals with default filter, use a lower threshold
            if home.listingType == "rental" && priceFilterIsDefault {
                return true  // Don't filter rentals by the sale-oriented price range
            }

            let priceDouble = NSDecimalNumber(decimal: price).doubleValue
            return priceDouble >= minPrice && (skipMaxPriceFilter || priceDouble <= maxPrice)
        }

        // Debug: Log after price filter
        if homes.count > 0 && filtered.count != homes.count {
            print("🔎 After price filter: \(filtered.count)/\(homes.count) homes (min: $\(Int(minPrice)), max: $\(Int(maxPrice)), skip max: \(skipMaxPriceFilter), skipAll: \(skipPriceFilter))")
        }

        // NOTE: City filtering is handled by searchByCity() at the database level
        // Do NOT filter by city here - it would filter out results before the DB search completes

        // Filter by bedrooms
        if let beds = selectedBedrooms {
            filtered = filtered.filter { home in
                guard let homeBeds = home.bedrooms else { return false }
                return homeBeds >= beds
            }
        }

        // Filter by bathrooms
        if let baths = selectedBathrooms {
            filtered = filtered.filter { home in
                guard let homeBaths = home.bathrooms else { return false }
                let homeBathsInt = NSDecimalNumber(decimal: homeBaths).intValue
                return homeBathsInt >= baths
            }
        }

        // Filter by tags/keywords/cities (must match ALL selected items)
        if !selectedTags.isEmpty {
            filtered = filtered.filter { home in
                // Check if home has ALL selected tags/keywords/cities
                for selectedKeyword in selectedTags {
                    let keywordLower = selectedKeyword.lowercased().replacingOccurrences(of: "#", with: "")
                    var hasMatch = false

                    // Check city match
                    if let city = home.city?.lowercased() {
                        if city == keywordLower || city.contains(keywordLower) {
                            hasMatch = true
                        }
                    }

                    // Check state match
                    if !hasMatch, let state = home.state?.lowercased() {
                        if state == keywordLower || state.contains(keywordLower) {
                            hasMatch = true
                        }
                    }

                    // Check tag match
                    if !hasMatch, let homeTags = home.tags {
                        // Map keyword to actual tag(s) using TagKeywordMapper
                        let matchingTags = TagKeywordMapper.findMatchingTags(for: selectedKeyword)

                        for homeTag in homeTags {
                            let homeTagLower = homeTag.lowercased().replacingOccurrences(of: "#", with: "")

                            // Direct match (e.g., searching "Pool" finds "#Pool")
                            if homeTagLower == keywordLower || homeTagLower.contains(keywordLower) {
                                hasMatch = true
                                break
                            }

                            // Keyword mapping match (e.g., searching "fixer" finds "#FixerUpper")
                            for matchingTag in matchingTags {
                                if homeTagLower == matchingTag.lowercased() {
                                    hasMatch = true
                                    break
                                }
                            }

                            if hasMatch { break }
                        }
                    }

                    // If this keyword/tag wasn't found, filter out this home
                    if !hasMatch {
                        return false
                    }
                }
                return true
            }
        }

        // Debug: Log final count if it differs from homes count
        if !selectedCity.isEmpty && filtered.count != homes.count {
            print("🔎 Final filteredHomes: \(filtered.count) (from \(homes.count) for city '\(selectedCity)')")
        }

        return filtered
    }

    // Check if any search filters are active
    var hasActiveFilters: Bool {
        !selectedCity.isEmpty ||
        selectedBedrooms != nil ||
        selectedBathrooms != nil ||
        minPrice > 25000 ||
        maxPrice < 49500000 ||  // Use same threshold as effectiveMaxPrice
        !selectedTags.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Collapsed search bar - tapping expands the panel
                if !showSearchPanel {
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSearchPanel = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))

                                if hasActiveFilters {
                                    // Show active filter summary
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            if !selectedCity.isEmpty {
                                                filterPill(selectedCity)
                                            }
                                            if let beds = selectedBedrooms {
                                                filterPill("\(beds)+ Beds")
                                            }
                                            if let baths = selectedBathrooms {
                                                filterPill("\(baths)+ Baths")
                                            }
                                            if minPrice > 25000 || maxPrice < 50000000 {
                                                filterPill(priceRangeText)
                                            }
                                            ForEach(selectedTags, id: \.self) { tag in
                                                filterPill(tag)
                                            }
                                        }
                                    }
                                } else {
                                    Text("Search for your dream home")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 15))
                                }

                                Spacer()

                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 18))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        // Clear/Reset button when filters are active
                        if hasActiveFilters {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    resetFilters()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }

                // Expanded search panel - compact layout to fit on one screen
                if showSearchPanel {
                    VStack(spacing: 0) {
                        // Header with close button
                        HStack {
                            Text("Search Filters")
                                .font(.system(size: 16, weight: .semibold))

                            Spacer()

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showSearchPanel = false
                                    isTagFieldFocused = false
                                    isCityFieldFocused = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                        // All filters in a compact non-scrolling layout
                        VStack(spacing: 12) {
                            // Row 1: City field with autocomplete dropdown
                            VStack(alignment: .leading, spacing: 4) {
                                Text("City")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)

                                // City text field with dropdown overlay
                                HStack(spacing: 6) {
                                    TextField("Enter city (e.g. Miami, New York)", text: $selectedCity)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14))
                                        .autocorrectionDisabled()
                                        .focused($isCityFieldFocused)
                                        .onChange(of: selectedCity) { oldValue, newValue in
                                            showCitySuggestions = !newValue.isEmpty && isCityFieldFocused
                                            print("🔎 City changed: '\(newValue)', focus: \(isCityFieldFocused), showSuggestions: \(showCitySuggestions), allCities: \(allCities.count)")
                                        }
                                        .onChange(of: isCityFieldFocused) { oldValue, newValue in
                                            // Show suggestions when field gains focus with existing text
                                            if newValue && !selectedCity.isEmpty {
                                                showCitySuggestions = true
                                            }
                                        }
                                        .onSubmit {
                                            showCitySuggestions = false
                                            isCityFieldFocused = false
                                            if !selectedCity.isEmpty {
                                                searchByCity()
                                            }
                                        }

                                    if !selectedCity.isEmpty && allCities.contains(where: { $0.lowercased() == selectedCity.lowercased() }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))
                                    }

                                    if !selectedCity.isEmpty {
                                        Button(action: {
                                            selectedCity = ""
                                            showCitySuggestions = false
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 14))
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            }
                            .zIndex(10) // Ensure city section is above other elements

                            // City suggestions dropdown - separate so it overlays below
                            if showCitySuggestions && !suggestedCities.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(suggestedCities.prefix(4), id: \.self) { city in
                                        Button(action: {
                                            selectedCity = city
                                            showCitySuggestions = false
                                            isCityFieldFocused = false
                                            searchByCity()
                                        }) {
                                            HStack {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundColor(.accentColor)
                                                    .font(.system(size: 12))
                                                Text(city)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)

                                        if city != suggestedCities.prefix(4).last {
                                            Divider()
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                                .zIndex(100) // Highest z-index to appear above everything
                            }

                            // Row 2: Listing Type, Beds, Baths (3-column)
                            HStack(spacing: 10) {
                                // Listing Type
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Type")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Menu {
                                        Button("All") { listingFilter = .all }
                                        Button("Sales") { listingFilter = .sales }
                                        Button("Rentals") { listingFilter = .rentals }
                                    } label: {
                                        HStack {
                                            Text(listingFilter.rawValue)
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                // Bedrooms
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Beds")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Menu {
                                        Button("Any") { selectedBedrooms = nil }
                                        ForEach(1...6, id: \.self) { num in
                                            Button("\(num)+") { selectedBedrooms = num }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedBedrooms.map { "\($0)+" } ?? "Any")
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                // Bathrooms
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Baths")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Menu {
                                        Button("Any") { selectedBathrooms = nil }
                                        ForEach(1...5, id: \.self) { num in
                                            Button("\(num)+") { selectedBathrooms = num }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedBathrooms.map { "\($0)+" } ?? "Any")
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Row 3: Price range
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Price Range")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)

                                PriceRangeSlider(minPrice: $minPrice, maxPrice: $maxPrice)
                            }

                            // Row 4: Tags (compact)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tags (optional)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)

                                // Selected tags as pills (horizontal scroll)
                                if !selectedTags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(selectedTags, id: \.self) { tag in
                                                HStack(spacing: 3) {
                                                    Text(tag)
                                                        .font(.system(size: 12, weight: .medium))
                                                    Button(action: {
                                                        selectedTags.removeAll { $0 == tag }
                                                        searchByTags()
                                                    }) {
                                                        Image(systemName: "xmark")
                                                            .font(.system(size: 9))
                                                    }
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue)
                                                .cornerRadius(12)
                                            }
                                        }
                                    }
                                    .frame(height: 26)
                                }

                                // Tag input field (compact)
                                ZStack(alignment: .topLeading) {
                                    TextField("motivated seller, fix and flip, pool...", text: $tagSearch)
                                        .textFieldStyle(.plain)
                                        .autocorrectionDisabled()
                                        .autocapitalization(.none)
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                        .focused($isTagFieldFocused)
                                        .onSubmit {
                                            addTag()
                                        }
                                        .onChange(of: tagSearch) { oldValue, newValue in
                                            showTagSuggestions = !newValue.isEmpty
                                        }
                                }

                                // Tag suggestions (compact dropdown)
                                if showTagSuggestions && !suggestedTags.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(suggestedTags.prefix(3), id: \.self) { tag in
                                            Button(action: {
                                                selectedTags.append(tag)
                                                tagSearch = ""
                                                showTagSuggestions = false
                                                searchByTags()
                                            }) {
                                                Text(tag)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.primary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 8)
                                            }
                                            .buttonStyle(.plain)

                                            if tag != suggestedTags.prefix(3).last {
                                                Divider()
                                            }
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                }
                            }

                            // Row 5: Action buttons
                            HStack(spacing: 10) {
                                Button(action: resetFilters) {
                                    Text("Reset")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }

                                Button(action: {
                                    isTagFieldFocused = false
                                    isCityFieldFocused = false
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showSearchPanel = false
                                    }
                                    // Only call the appropriate search function
                                    // Don't call searchByTags if empty - it would reset homes to allHomes
                                    if !selectedCity.isEmpty {
                                        searchByCity()
                                    } else if !selectedTags.isEmpty {
                                        // Only search by tags if no city is selected
                                        searchByTags()
                                    }
                                }) {
                                    Text("Search")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.accentColor)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color(.systemGray6))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()

                if isLoading || isSearchingCity {
                    // Loading skeleton with message
                    VStack(spacing: 16) {
                        if isSearchingCity {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Searching \(selectedCity)...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(0..<3, id: \.self) { _ in
                                    LoadingSkeletonView()
                                        .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                } else if filteredHomes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: hasActiveFilters ? "magnifyingglass" : "dollarsign.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        if hasActiveFilters {
                            // City or other filters are active but no results
                            Text("No results found")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            if !selectedCity.isEmpty && homes.count > 0 {
                                // City search found results but price filter removed them
                                Text("Found \(homes.count) in \(selectedCity), but none match your price range. Try adjusting your filters.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            } else if !selectedCity.isEmpty {
                                Text("No properties found in \(selectedCity)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            } else {
                                Text("Try adjusting your search filters")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text("No homes yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Be the first to post a property!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredHomes) { home in
                                    HomePostView(home: home, searchText: $tagSearch)
                                        .id(home.id)  // Use just home.id for scroll targeting
                                        .padding(.bottom, 16)
                                }
                            }
                        }
                        .onAppear {
                            // Check if there's a pending scroll target when the ScrollView appears
                            if let targetId = pendingScrollTarget {
                                print("📜 PriceFeedView: Found pending scroll target on appear: \(targetId)")
                                // Scroll instantly without animation for seamless transition
                                scrollProxy.scrollTo(targetId, anchor: .center)
                                pendingScrollTarget = nil
                            }
                        }
                        .onChange(of: pendingScrollTarget) { oldValue, newValue in
                            // React to pending scroll target changes while view is visible
                            if let targetId = newValue {
                                print("📜 PriceFeedView: Scroll target changed to: \(targetId)")
                                // Scroll instantly without animation
                                scrollProxy.scrollTo(targetId, anchor: .center)
                                pendingScrollTarget = nil
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                isSearchFocused = false
                isTagFieldFocused = false
                isCityFieldFocused = false
                showTagSuggestions = false
                showCitySuggestions = false
            }
            .onChange(of: listingFilter) { oldValue, newValue in
                // If a city search is active, re-search with new filter
                // Otherwise load all homes
                if !selectedCity.isEmpty {
                    searchByCity()
                } else {
                    loadHomes()
                }
            }
            .onChange(of: cityLocationManager.cityName) { oldValue, newValue in
                if let city = newValue, !city.isEmpty {
                    userCurrentCity = city
                    // Don't auto-fill - let user see the placeholder and choose their own city
                    print("📍 Detected user's current city: \(city)")
                }
            }
            .onAppear {
                loadHomes()
                loadAllCities()
                cityLocationManager.requestLocation()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshFeed"))) { _ in
                // Respect city search when refreshing
                if !selectedCity.isEmpty {
                    searchByCity()
                } else {
                    loadHomes()
                }
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("ScrollToHome"))) { notification in
                // Capture scroll target at VStack level (always exists) and store for ScrollViewReader
                if let homeId = notification.userInfo?["homeId"] as? UUID {
                    print("📜 PriceFeedView received ScrollToHome notification: \(homeId)")
                    pendingScrollTarget = homeId
                }
            }
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // Helper view for filter pills in collapsed state (dark background)
    @ViewBuilder
    func filterPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue)
            .cornerRadius(12)
    }

    // Format price range for display
    var priceRangeText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0

        let minStr = minPrice >= 1000000 ? "$\(Int(minPrice / 1000000))M" : "$\(Int(minPrice / 1000))K"
        let maxStr = maxPrice >= 1000000 ? "$\(Int(maxPrice / 1000000))M" : "$\(Int(maxPrice / 1000))K"

        if maxPrice >= 50000000 {
            return "\(minStr)+"
        }
        return "\(minStr) - \(maxStr)"
    }

    func resetFilters() {
        selectedCity = ""
        selectedBedrooms = nil
        selectedBathrooms = nil
        minPrice = 25000
        maxPrice = 50000000
        selectedTags = []
        tagSearch = ""
        showTagSuggestions = false
        homes = allHomes
    }

    func addTag() {
        let cleanTag = tagSearch.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")

        if !cleanTag.isEmpty && !selectedTags.contains(cleanTag) {
            selectedTags.append(cleanTag)
            tagSearch = ""
            showTagSuggestions = false
            // Trigger database search for better results
            searchByTags()
        }
    }

    func searchByTags() {
        guard !selectedTags.isEmpty else {
            // If no tags selected, restore original homes
            // But only if no city search is active - city search takes priority
            if selectedCity.isEmpty {
                homes = allHomes
            }
            return
        }

        Task {
            do {
                // Search database for homes matching any of the selected keywords
                var orFilters: [String] = []
                for keyword in selectedTags {
                    let pattern = "%\(keyword)%"
                    orFilters.append("city.ilike.\(pattern)")
                    orFilters.append("state.ilike.\(pattern)")
                }

                let orFilter = orFilters.joined(separator: ",")

                var query = SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .not("price", operator: .is, value: "null")
                    .or(orFilter)

                // Apply listing type filter
                switch listingFilter {
                case .rentals:
                    query = query.eq("listing_type", value: "rental")
                case .sales:
                    query = query.eq("listing_type", value: "sale")
                case .all:
                    break
                }

                let cityResults: [Home] = try await query
                    .order("price", ascending: true)
                    .limit(100)
                    .execute()
                    .value

                print("🔍 Database search for \(selectedTags) returned \(cityResults.count) city matches")

                // Merge with existing homes (some may match by tags only, not city)
                await MainActor.run {
                    var mergedHomes = allHomes
                    for home in cityResults {
                        if !mergedHomes.contains(where: { $0.id == home.id }) {
                            mergedHomes.append(home)
                        }
                    }
                    homes = mergedHomes
                }
            } catch {
                print("❌ Error searching by tags: \(error)")
            }
        }
    }

    /// Search by city from database - fetches ALL homes matching the city
    func searchByCity() {
        print("🚀🚀🚀 searchByCity() CALLED with city: '\(selectedCity)'")

        guard !selectedCity.isEmpty else {
            // If city is cleared, restore all homes
            print("⚠️ City is empty, restoring all homes")
            homes = allHomes
            return
        }

        // Show loading indicator
        isSearchingCity = true
        print("🔍 Starting city search for: '\(selectedCity)'")

        Task {
            do {
                // Use case-insensitive pattern matching
                let pattern = "%\(selectedCity)%"
                print("🔍 Using pattern: \(pattern)")

                var query = SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .not("price", operator: .is, value: "null")
                    .ilike("city", value: pattern)

                // Apply listing type filter
                switch listingFilter {
                case .rentals:
                    query = query.eq("listing_type", value: "rental")
                case .sales:
                    query = query.eq("listing_type", value: "sale")
                case .all:
                    break
                }

                // No limit - fetch ALL properties for this city
                let cityResults: [Home] = try await query
                    .order("price", ascending: true)
                    .execute()
                    .value

                print("🏙️ Database search for city '\(selectedCity)' returned \(cityResults.count) matches")
                for (i, home) in cityResults.enumerated() {
                    let priceValue = NSDecimalNumber(decimal: home.price ?? 0).intValue
                    print("   \(i+1). \(home.city ?? "N/A") - $\(priceValue) - \(home.title ?? "No title")")
                }

                // Use ONLY the city results when a city is selected
                // Store locally first to avoid any async issues
                let results = cityResults
                let resultsCount = results.count

                await MainActor.run {
                    print("🏙️ MainActor: Setting homes array with \(resultsCount) results...")
                    // Set homes first, then immediately set loading to false in the same run loop
                    self.homes = results
                    self.isSearchingCity = false
                    print("🏙️ MainActor: homes.count = \(self.homes.count), isSearchingCity = \(self.isSearchingCity)")
                    print("🏙️ MainActor: Price filter range: $\(Int(self.minPrice)) - $\(Int(self.maxPrice))")
                }
            } catch {
                print("❌ Error searching by city: \(error)")
                await MainActor.run {
                    isSearchingCity = false
                }
            }
        }
    }

    func loadHomes() {
        isLoading = true

        Task {
            do {
                print("📥 Loading homes by price (Filter: \(listingFilter.rawValue))...")

                var query = SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .not("price", operator: .is, value: "null")

                // Apply listing type filter
                switch listingFilter {
                case .rentals:
                    query = query.eq("listing_type", value: "rental")
                case .sales:
                    query = query.eq("listing_type", value: "sale")
                case .all:
                    break // No filter needed
                }

                // Load more homes to have better city/tag coverage
                let response: [Home] = try await query
                    .order("price", ascending: true)
                    .limit(200)  // Load more for better search coverage
                    .execute()
                    .value

                print("✅ Loaded \(response.count) homes with prices")
                homes = response
                allHomes = response
                isLoading = false
            } catch {
                print("❌ Error loading homes: \(error)")
                isLoading = false
            }
        }
    }

    /// Load all unique cities from the database for search autocomplete
    func loadAllCities() {
        Task {
            do {
                // Fetch all homes just to get unique cities (lightweight query)
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("city")
                    .eq("is_active", value: true)
                    .not("city", operator: .is, value: "null")
                    .execute()
                    .value

                var cities: Set<String> = []
                for home in response {
                    if let city = home.city, !city.isEmpty {
                        // Clean up city names (trim whitespace)
                        let cleanCity = city.trimmingCharacters(in: .whitespaces)
                        if !cleanCity.isEmpty {
                            cities.insert(cleanCity)
                        }
                    }
                }

                await MainActor.run {
                    allCities = Array(cities).sorted()
                    print("🏙️ Loaded \(allCities.count) unique cities for search: \(allCities)")
                }
            } catch {
                print("❌ Error loading cities: \(error)")
            }
        }
    }
}

#Preview {
    PriceFeedView()
}

// MARK: - City Location Manager
/// Location manager that gets the user's current city via reverse geocoding
class CityLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    @Published var cityName: String?
    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        self.location = location.coordinate

        // Reverse geocode to get city name
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self?.cityName = placemark.locality ?? placemark.subAdministrativeArea
                    print("📍 Reverse geocoded city: \(self?.cityName ?? "unknown")")
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}


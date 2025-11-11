//
//  PriceFeedView.swift
//  Ugly Homes
//
//  Feed sorted by price with filters
//

import SwiftUI

struct PriceFeedView: View {
    @State private var homes: [Home] = []
    @State private var allHomes: [Home] = []
    @State private var isLoading = true
    @State private var sortOrder: PriceSortOrder = .lowToHigh
    @State private var listingFilter: ListingFilter = .all
    @State private var tagSearch = ""
    @State private var selectedTags: [String] = []
    @State private var showTagSuggestions = false
    @FocusState private var isSearchFocused: Bool

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

    // Filter tags based on search
    var suggestedTags: [String] {
        guard !tagSearch.isEmpty else { return [] }
        let search = tagSearch.lowercased().replacingOccurrences(of: "#", with: "")
        return availableTags.filter { tag in
            tag.lowercased().contains(search) && !selectedTags.contains(tag)
        }.prefix(5).map { $0 }
    }

    enum PriceSortOrder: String, CaseIterable {
        case lowToHigh = "Low to High"
        case highToLow = "High to Low"
    }

    enum ListingFilter: String, CaseIterable {
        case all = "All"
        case rentals = "Rentals"
        case sales = "Sales"
    }

    var filteredHomes: [Home] {
        var filtered = homes

        // Filter by tags (must match ALL selected tags)
        if !selectedTags.isEmpty {
            filtered = filtered.filter { home in
                guard let homeTags = home.tags else { return false }

                // Check if home has ALL selected tags
                for selectedTag in selectedTags {
                    let tagLower = selectedTag.lowercased().replacingOccurrences(of: "#", with: "")
                    let hasTag = homeTags.contains { homeTag in
                        homeTag.lowercased().contains(tagLower)
                    }
                    if !hasTag {
                        return false
                    }
                }
                return true
            }
        }

        print("🔍 Tags: \(selectedTags) - \(filtered.count) results")
        return filtered
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tag search bar with autocomplete
                HStack(spacing: 8) {
                    // Tag search field with selected tags
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))

                        // Show selected tags as blue pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.system(size: 13, weight: .medium))
                                        Button(action: {
                                            selectedTags.removeAll { $0 == tag }
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .cornerRadius(15)
                                }

                                TextField("Search tags", text: $tagSearch)
                                    .textFieldStyle(.plain)
                                    .autocorrectionDisabled()
                                    .autocapitalization(.none)
                                    .font(.system(size: 15))
                                    .frame(minWidth: 100)
                                    .focused($isSearchFocused)
                                    .onSubmit {
                                        addTag()
                                    }
                                    .onChange(of: tagSearch) { oldValue, newValue in
                                        showTagSuggestions = !newValue.isEmpty
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        isSearchFocused = true
                    }
                    .background(alignment: .top) {
                        // Tag suggestions dropdown
                        if showTagSuggestions && !suggestedTags.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(suggestedTags, id: \.self) { tag in
                                    Button(action: {
                                        selectedTags.append(tag)
                                        tagSearch = ""
                                        showTagSuggestions = false
                                    }) {
                                        HStack {
                                            Text(tag)
                                                .font(.system(size: 14))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemBackground))
                                    }
                                    .buttonStyle(.plain)

                                    if tag != suggestedTags.last {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            .offset(y: 38)
                            .frame(width: 200)
                            .zIndex(2000)
                        }
                    }

                    Menu {
                        Section(header: Text("Filter by Type")) {
                            Picker("Filter", selection: $listingFilter) {
                                ForEach(ListingFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                        }

                        Section(header: Text("Sort by Price")) {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(PriceSortOrder.allCases, id: \.self) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .zIndex(1)

                Divider()

                if isLoading {
                    // Loading skeleton
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { _ in
                                LoadingSkeletonView()
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                } else if filteredHomes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: selectedTags.isEmpty ? "dollarsign.circle" : "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        if selectedTags.isEmpty {
                            Text("No homes yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Be the first to post a property!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Text("No results found")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Try searching for a different property")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredHomes) { home in
                                HomePostView(home: home, searchText: $tagSearch)
                                    .id("\(home.id)-\(home.soldStatus ?? "none")-\(home.updatedAt.timeIntervalSince1970)-\(home.tags?.joined(separator: ",") ?? "")")
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                isSearchFocused = false
                showTagSuggestions = false
            }
            .onChange(of: sortOrder) { oldValue, newValue in
                loadHomes()
            }
            .onChange(of: listingFilter) { oldValue, newValue in
                loadHomes()
            }
            .onAppear {
                loadHomes()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshFeed"))) { _ in
                loadHomes()
            }
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func addTag() {
        let cleanTag = tagSearch.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")

        if !cleanTag.isEmpty && !selectedTags.contains(cleanTag) {
            selectedTags.append(cleanTag)
            tagSearch = ""
            showTagSuggestions = false
        }
    }

    func loadHomes() {
        isLoading = true

        Task {
            do {
                print("📥 Loading homes by price (Order: \(sortOrder.rawValue), Filter: \(listingFilter.rawValue))...")

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

                let response: [Home] = try await query
                    .order("price", ascending: sortOrder == .lowToHigh)
                    .limit(30)  // Limit initial load for faster performance
                    .execute()
                    .value

                print("✅ Loaded \(response.count) homes with prices (limited for performance)")
                homes = response
                allHomes = response
                isLoading = false
            } catch {
                print("❌ Error loading homes: \(error)")
                isLoading = false
            }
        }
    }
}

#Preview {
    PriceFeedView()
}

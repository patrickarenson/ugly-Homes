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
    @State private var showCreatePost = false
    @State private var sortOrder: PriceSortOrder = .lowToHigh
    @State private var listingFilter: ListingFilter = .all
    @State private var searchText = ""

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
        if searchText.isEmpty {
            return homes
        } else {
            let filtered = allHomes.filter { home in
                let search = searchText.lowercased()

                // Debug: Print profile info for first home
                if home.id == allHomes.first?.id {
                    print("🔍 DEBUG - First home profile: \(home.profile?.username ?? "NO USERNAME")")
                    print("🔍 DEBUG - Searching for: '\(searchText)'")
                }

                // Search by tags (hashtags)
                if let tags = home.tags {
                    for tag in tags {
                        if tag.lowercased().contains(search) {
                            return true
                        }
                    }
                }

                // Search by username
                if let username = home.profile?.username, username.lowercased().contains(search) {
                    print("✅ Found match in username: \(username)")
                    return true
                }

                // Search by address, city, state, zip
                if let address = home.address, address.lowercased().contains(search) {
                    return true
                }
                if let city = home.city, city.lowercased().contains(search) {
                    return true
                }
                if let state = home.state, state.lowercased().contains(search) {
                    return true
                }
                if let zipCode = home.zipCode, zipCode.contains(searchText) {
                    return true
                }
                return false
            }

            print("🔍 Search for '\(searchText)' returned \(filtered.count) results")
            return filtered
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar - positioned at very top
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))

                        TextField("Search by tag, username, or address", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

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

                    Button(action: {
                        showCreatePost = true
                    }) {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

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
                        Image(systemName: searchText.isEmpty ? "dollarsign.circle" : "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        if searchText.isEmpty {
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
                                HomePostView(home: home, searchText: $searchText)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                hideKeyboard()
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .onChange(of: showCreatePost) { oldValue, newValue in
                if !newValue {
                    loadHomes()
                }
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
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

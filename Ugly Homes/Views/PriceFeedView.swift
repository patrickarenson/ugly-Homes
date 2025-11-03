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
            return allHomes.filter { home in
                if let username = home.profile?.username, username.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                if let address = home.address, address.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                if let city = home.city, city.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                if let state = home.state, state.lowercased().contains(searchText.lowercased()) {
                    return true
                }
                if let zipCode = home.zipCode, zipCode.contains(searchText) {
                    return true
                }
                return false
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))

                        TextField("Search", text: $searchText)
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
                        Picker("Filter", selection: $listingFilter) {
                            ForEach(ListingFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                    }

                    Menu {
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(PriceSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
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
                .padding(.vertical, 10)

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
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredHomes) { home in
                                HomePostView(home: home)
                                    .padding(.bottom, 16)
                            }

                            if filteredHomes.isEmpty && !searchText.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No results found")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
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
}

#Preview {
    PriceFeedView()
}

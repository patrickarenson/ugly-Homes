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
    @State private var isLoading = false
    @State private var showCreatePost = false
    @State private var sortOrder: PriceSortOrder = .lowToHigh
    @State private var searchText = ""

    enum PriceSortOrder: String, CaseIterable {
        case lowToHigh = "Low to High"
        case highToLow = "High to Low"
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

                ZStack {
                    if isLoading {
                        ProgressView()
                    } else if filteredHomes.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: searchText.isEmpty ? "dollarsign.slash.circle" : "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text(searchText.isEmpty ? "No priced homes yet" : "No results found")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredHomes) { home in
                                    HomePostView(home: home)
                                        .padding(.bottom, 16)
                                }
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
                print("📥 Loading homes by price (Order: \(sortOrder.rawValue))...")

                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .not("price", operator: .is, value: "null")
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

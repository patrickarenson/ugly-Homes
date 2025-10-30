//
//  LocationFeedView.swift
//  Ugly Homes
//
//  Feed sorted by location with state filter
//

import SwiftUI

struct LocationFeedView: View {
    @State private var homes: [Home] = []
    @State private var allHomes: [Home] = []
    @State private var isLoading = false
    @State private var showCreatePost = false
    @State private var selectedState = "All"
    @State private var searchText = ""

    let usStates = ["All", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA",
                    "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY",
                    "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX",
                    "UT", "VT", "VA", "WA", "WV", "WI", "WY"]

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
                        Picker("State", selection: $selectedState) {
                            ForEach(usStates, id: \.self) { state in
                                Text(state).tag(state)
                            }
                        }
                    } label: {
                        Image(systemName: "map")
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
                            Image(systemName: searchText.isEmpty ? "map.slash" : "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text(searchText.isEmpty ? "No homes in this area" : "No results found")
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
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .onChange(of: showCreatePost) { oldValue, newValue in
                if !newValue {
                    loadHomes()
                }
            }
            .onChange(of: selectedState) { oldValue, newValue in
                loadHomes()
            }
            .onAppear {
                loadHomes()
            }
        }
    }

    func loadHomes() {
        isLoading = true

        Task {
            do {
                print("📥 Loading homes by location (State: \(selectedState))...")

                var query = SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)

                if selectedState != "All" {
                    query = query.eq("state", value: selectedState)
                }

                let response: [Home] = try await query
                    .order("state", ascending: true)
                    .order("city", ascending: true)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) homes")
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
    LocationFeedView()
}

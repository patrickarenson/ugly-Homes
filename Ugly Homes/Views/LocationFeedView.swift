//
//  LocationFeedView.swift
//  Ugly Homes
//
//  Feed sorted by location with state filter
//

import SwiftUI
import MapKit
import CoreLocation

struct LocationFeedView: View {
    @State private var homes: [Home] = []
    @State private var allHomes: [Home] = []
    @State private var isLoading = true
    @State private var showCreatePost = false
    @State private var selectedState = "All"
    @State private var searchText = ""
    @State private var showMapView = true
    @State private var selectedHome: Home?
    @State private var showOpenHouseList = false
    @StateObject private var locationManager = LocationManager()
    @State private var savedOpenHouseIds: Set<UUID> = []
    @State private var bookmarkedHomeIds: Set<UUID> = []
    @State private var highlightedHomeId: UUID? = nil
    @State private var isLoadingHighlightedHome = false
    @State private var lastViewedOpenHouseCount = UserDefaults.standard.integer(forKey: "lastViewedOpenHouseCount")
    @State private var savedScrollHomeId: UUID? = nil // Saved for scroll position restoration

    let usStates = ["All", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA",
                    "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY",
                    "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX",
                    "UT", "VT", "VA", "WA", "WV", "WI", "WY"]

    var filteredHomes: [Home] {
        if searchText.isEmpty {
            return homes
        } else {
            let filtered = allHomes.filter { home in
                let search = searchText.lowercased()

                // Debug: Print profile info for first home
                if home.id == allHomes.first?.id {
                    print("🔍 [LocationView] DEBUG - First home profile: \(home.profile?.username ?? "NO USERNAME")")
                    print("🔍 [LocationView] DEBUG - Searching for: '\(searchText)'")
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
                    print("✅ [LocationView] Found match in username: \(username)")
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

            print("🔍 [LocationView] Search for '\(searchText)' returned \(filtered.count) results")
            return filtered
        }
    }

    // All saved upcoming open houses (not expired yet)
    var upcomingOpenHouses: [Home] {
        let now = Date()

        let filtered = allHomes.filter { home in
            guard home.openHousePaid == true,
                  let startDate = home.openHouseDate,
                  savedOpenHouseIds.contains(home.id) else {
                return false
            }

            let endDate = home.openHouseEndDate ?? startDate.addingTimeInterval(7200)
            // Only show if the open house hasn't ended yet
            return endDate >= now
        }
        .sorted { home1, home2 in
            (home1.openHouseDate ?? Date()) < (home2.openHouseDate ?? Date())
        }

        return filtered
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header bar (search bar only shows in list view)
                HStack(spacing: 12) {
                    // Back button - only show when on map with highlighted property
                    if showMapView && savedScrollHomeId != nil {
                        Button(action: {
                            // Post notification to switch back to trending tab with SAVED homeId
                            print("🔙 Back button clicked, sending homeId: \(savedScrollHomeId?.uuidString ?? "nil")")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ReturnToTrendingFromMap"),
                                object: nil,
                                userInfo: ["homeId": savedScrollHomeId as Any]
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    // Open House List button - COMMENTED OUT for App Store submission
                    // TODO: Re-enable once fully tested
//                    Button(action: {
//                        showOpenHouseList = true
//                    }) {
//                        ZStack(alignment: .topTrailing) {
//                            Image(systemName: "signpost.right.fill")
//                                .font(.system(size: 24))
//                                .foregroundColor(.green)
//
//                            // Badge showing count of NEW upcoming open houses
//                            if upcomingOpenHouses.count > lastViewedOpenHouseCount {
//                                Text("\(upcomingOpenHouses.count - lastViewedOpenHouseCount)")
//                                    .font(.system(size: 10, weight: .bold))
//                                    .foregroundColor(.white)
//                                    .padding(.horizontal, 4)
//                                    .padding(.vertical, 2)
//                                    .background(Color.red)
//                                    .clipShape(Circle())
//                                    .offset(x: 8, y: -8)
//                            }
//                        }
//                    }

                    // Search bar - only show in list view
                    if !showMapView {
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
                    } else {
                        Spacer()
                    }

                    // Toggle between map and list view
                    Button(action: {
                        showMapView.toggle()
                    }) {
                        Image(systemName: showMapView ? "list.bullet" : "map")
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

                // Show either map or list view
                if showMapView {
                    ZStack {
                        PropertyMapView(
                            homes: filteredHomes,
                            userLocation: locationManager.location,
                            selectedHome: $selectedHome,
                            bookmarkedHomeIds: bookmarkedHomeIds,
                            highlightedHomeId: highlightedHomeId,
                            isLoadingHighlightedHome: $isLoadingHighlightedHome
                        )
                        .onTapGesture {
                            hideKeyboard()
                        }

                        // Loading overlay when finding property on map
                        if isLoadingHighlightedHome {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)

                                Text("Finding property on map...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(20)
                            .background(Color(.systemBackground).opacity(0.95))
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        }
                    }
                } else {
                    // List view
                    ZStack {
                        if filteredHomes.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: searchText.isEmpty ? "map" : "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)

                                if searchText.isEmpty {
                                    Text("No homes in this area yet")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text("Be the first to post a property here!")
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
                                            .id("\(home.id)-\(home.soldStatus ?? "none")-\(home.updatedAt.timeIntervalSince1970)-\(home.tags?.joined(separator: ",") ?? "")")
                                            .padding(.bottom, 16)
                                    }
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        hideKeyboard()
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
            .sheet(item: $selectedHome) { home in
                NavigationView {
                    ScrollView {
                        HomePostView(home: home, searchText: $searchText)
                            .id("\(home.id)-\(home.soldStatus ?? "none")-\(home.updatedAt.timeIntervalSince1970)-\(home.tags?.joined(separator: ",") ?? "")")
                    }
                    .navigationTitle("Property")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                selectedHome = nil
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showOpenHouseList) {
                NavigationView {
                    OpenHouseListView(
                        homes: upcomingOpenHouses,
                        userLocation: locationManager.location,
                        onSelectHome: { home in
                            showOpenHouseList = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedHome = home
                            }
                        },
                        onDeleteHome: { home in
                            deleteSavedOpenHouse(home)
                        }
                    )
                    .navigationTitle("Nearby Open Houses")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showOpenHouseList = false
                            }
                        }
                    }
                }
            }
            .onChange(of: showCreatePost) { oldValue, newValue in
                if !newValue {
                    loadHomes()
                }
            }
            .onAppear {
                print("🗺️ LocationFeedView appeared")
                // Always reset to map view when user taps the map icon
                showMapView = true
                loadHomes()
                loadSavedOpenHouses()
                loadBookmarks()
                locationManager.requestLocation()
            }
            .onChange(of: showOpenHouseList) { oldValue, newValue in
                // Reload saved open houses when opening the list to get latest
                if newValue {
                    print("🏠 Opening open house list, refreshing saved items")
                    loadSavedOpenHouses(markAsViewed: true)
                }
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshOpenHouseList"))) { _ in
                print("🔔 Received RefreshOpenHouseList notification")
                loadSavedOpenHouses()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("RefreshFeed"))) { _ in
                loadHomes()
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("ShowHomeOnMap"))) { notification in
                if let homeId = notification.userInfo?["homeId"] as? UUID {
                    print("🗺️ LocationFeedView received ShowHomeOnMap for: \(homeId)")
                    highlightedHomeId = homeId
                    savedScrollHomeId = homeId // Save for scroll position restoration
                    showMapView = true // Ensure map is showing

                    // Always show loading initially
                    isLoadingHighlightedHome = true

                    // Safety timeout - turn off loading after 3 seconds max (should be instant with fallback)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.isLoadingHighlightedHome {
                            print("⏱️ Loading timeout - turning off loading indicator after 3s")
                            self.isLoadingHighlightedHome = false
                        }
                    }

                    // If homes aren't loaded yet, load them
                    if homes.isEmpty {
                        print("🔄 Homes not loaded yet, loading now...")
                        loadHomesAndZoom(to: homeId)
                    } else {
                        // Check if the highlighted home is in the homes array
                        if !homes.contains(where: { $0.id == homeId }) {
                            print("⚠️ Highlighted home not in homes array (may be filtered out), loading it...")
                            loadAndAddHighlightedHome(homeId)
                        } else {
                            print("✅ Highlighted home found in homes array")
                            // PropertyMapView will automatically geocode and update region via its onChange modifiers
                            isLoadingHighlightedHome = false
                        }
                    }
                }
            }
            .onReceive(Foundation.NotificationCenter.default.publisher(for: Foundation.Notification.Name("ClearMapHighlight"))) { _ in
                print("🗺️ Clearing map highlight")
                highlightedHomeId = nil
                savedScrollHomeId = nil
                isLoadingHighlightedHome = false
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
                    .order("created_at", ascending: false)  // Show newest properties first
                    .limit(100)  // Increased limit to show more properties across all states
                    .execute()
                    .value

                // Filter out sold/leased properties and projects from map view
                // Projects are design inspiration, not real estate listings
                var activeListings = response.filter { home in
                    let isNotSoldOrLeased = home.soldStatus == nil || (home.soldStatus != "sold" && home.soldStatus != "leased")
                    let isNotProject = home.postType != "project"
                    return isNotSoldOrLeased && isNotProject
                }

                // IMPORTANT: Preserve highlighted home if it exists (don't remove it when refreshing)
                if let highlightedId = highlightedHomeId,
                   let existingHighlightedHome = homes.first(where: { $0.id == highlightedId }),
                   !activeListings.contains(where: { $0.id == highlightedId }) {
                    // Add highlighted home back to the beginning
                    activeListings.insert(existingHighlightedHome, at: 0)
                    print("🎯 Preserved highlighted home in homes array after refresh")
                }

                print("✅ Loaded \(response.count) homes, showing \(activeListings.count) active listings (filtered out sold/leased/projects)")
                homes = activeListings
                allHomes = activeListings
                isLoading = false
            } catch {
                print("❌ Error loading homes: \(error)")
                isLoading = false
            }
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func loadSavedOpenHouses(markAsViewed: Bool = false) {
        Task {
            do {
                print("📅 Loading saved open houses...")

                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct SavedOpenHouse: Codable {
                    let homeId: UUID

                    enum CodingKeys: String, CodingKey {
                        case homeId = "home_id"
                    }
                }

                let response: [SavedOpenHouse] = try await SupabaseManager.shared.client
                    .from("saved_open_houses")
                    .select("home_id")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                await MainActor.run {
                    savedOpenHouseIds = Set(response.map { $0.homeId })
                    print("✅ Loaded \(savedOpenHouseIds.count) saved open houses")
                    print("   Saved IDs: \(savedOpenHouseIds.map { $0.uuidString })")
                    print("   Upcoming open houses count: \(upcomingOpenHouses.count)")

                    // If user opened the list, save the count to mark as viewed
                    if markAsViewed {
                        lastViewedOpenHouseCount = upcomingOpenHouses.count
                        UserDefaults.standard.set(lastViewedOpenHouseCount, forKey: "lastViewedOpenHouseCount")
                        print("📝 Saved viewed count: \(lastViewedOpenHouseCount)")
                    }
                }
            } catch {
                print("❌ Error loading saved open houses: \(error)")
            }
        }
    }

    func deleteSavedOpenHouse(_ home: Home) {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                print("🗑️ Deleting saved open house: \(home.id)")

                try await SupabaseManager.shared.client
                    .from("saved_open_houses")
                    .delete()
                    .eq("home_id", value: home.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                print("✅ Deleted saved open house")

                // Reload the saved open houses list
                loadSavedOpenHouses()
            } catch {
                print("❌ Error deleting saved open house: \(error)")
            }
        }
    }

    func loadBookmarks() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct BookmarkRecord: Decodable {
                    let home_id: UUID
                }

                let bookmarks: [BookmarkRecord] = try await SupabaseManager.shared.client
                    .from("bookmarks")
                    .select("home_id")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                await MainActor.run {
                    bookmarkedHomeIds = Set(bookmarks.map { $0.home_id })
                    print("✅ Loaded \(bookmarkedHomeIds.count) bookmarked homes for map")
                }
            } catch {
                print("❌ Error loading bookmarks: \(error)")
            }
        }
    }

    func loadHomesAndZoom(to homeId: UUID) {
        Task {
            do {
                print("📥 Loading specific home to highlight on map...")

                // First, load the specific home we want to highlight
                let highlightedResponse: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("id", value: homeId.uuidString)
                    .execute()
                    .value

                // Then load all other homes for the map
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("is_active", value: true)
                    .eq("is_archived", value: false)
                    .order("state", ascending: true)
                    .order("city", ascending: true)
                    .limit(50)
                    .execute()
                    .value

                // Combine highlighted home with all other homes (avoid duplicates)
                var allLoadedHomes = response
                if let highlightedHome = highlightedResponse.first,
                   !allLoadedHomes.contains(where: { $0.id == highlightedHome.id }) {
                    allLoadedHomes.insert(highlightedHome, at: 0)
                }

                // Filter out sold/leased properties and projects
                let activeListings = allLoadedHomes.filter { home in
                    // Keep the highlighted home regardless of status
                    if home.id == homeId {
                        return true
                    }
                    let isNotSoldOrLeased = home.soldStatus == nil || (home.soldStatus != "sold" && home.soldStatus != "leased")
                    let isNotProject = home.postType != "project"
                    return isNotSoldOrLeased && isNotProject
                }

                await MainActor.run {
                    print("✅ Loaded \(activeListings.count) homes for map (including highlighted)")
                    homes = activeListings
                    allHomes = activeListings
                    isLoading = false
                    isLoadingHighlightedHome = false
                }
            } catch {
                print("❌ Error loading homes: \(error)")
                await MainActor.run {
                    isLoading = false
                    isLoadingHighlightedHome = false
                }
            }
        }
    }

    func loadAndAddHighlightedHome(_ homeId: UUID) {
        Task {
            do {
                print("📥 Loading highlighted home to add to map...")

                // Load the specific home we want to highlight
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("id", value: homeId.uuidString)
                    .execute()
                    .value

                if let highlightedHome = response.first {
                    await MainActor.run {
                        print("✅ Loaded highlighted home, adding to map")
                        // Add to the beginning of the homes array
                        homes.insert(highlightedHome, at: 0)
                        allHomes = homes
                        // PropertyMapView will automatically geocode and update region when homes.count changes
                        isLoadingHighlightedHome = false
                    }
                } else {
                    print("❌ Highlighted home not found in database")
                    await MainActor.run {
                        isLoadingHighlightedHome = false
                    }
                }
            } catch {
                print("❌ Error loading highlighted home: \(error)")
                await MainActor.run {
                    isLoadingHighlightedHome = false
                }
            }
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        authorizationStatus = manager.authorizationStatus

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
        location = locations.first?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - Property Map View
struct PropertyMapView: View {
    let homes: [Home]
    let userLocation: CLLocationCoordinate2D?
    @Binding var selectedHome: Home?
    let bookmarkedHomeIds: Set<UUID>
    let highlightedHomeId: UUID?
    @Binding var isLoadingHighlightedHome: Bool
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 28.5383, longitude: -81.3792),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
    )
    @State private var geocodedCoordinates: [UUID: CLLocationCoordinate2D] = [:]
    @State private var isGeocoding = false

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(mapAnnotations) { annotation in
                Annotation("", coordinate: annotation.coordinate) {
                    annotationView(for: annotation)
                }
            }
        }
        .onAppear {
            updateRegion()
            geocodeAllHomes()
        }
        .onChange(of: highlightedHomeId) { _, newValue in
            print("🗺️ PropertyMapView detected highlighted ID change: \(String(describing: newValue))")
            if newValue != nil {
                // Trigger geocoding for the new highlighted home
                geocodeAllHomes()
            }
            updateRegion()
        }
        .onChange(of: homes.count) { _, _ in
            // When homes are loaded, update region if there's a highlighted home
            if highlightedHomeId != nil {
                print("🗺️ Homes loaded, geocoding and updating region for highlighted home")
                geocodeAllHomes()
                updateRegion()
            }
        }
    }

    @ViewBuilder
    func annotationView(for annotation: PropertyMapAnnotation) -> some View {
        if annotation.isUserLocation {
            // User's current location - blue pulsing dot
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(radius: 3)
        } else if let home = annotation.home, highlightedHomeId == home.id {
            // Highlighted home from post - black pin (stands out!)
            VStack(spacing: 0) {
                // Price tag
                if let price = home.price {
                    Text("$\(formatPrice(price))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black)
                        .cornerRadius(8)
                }

                // Black pin
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.black)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    )
                    .shadow(radius: 3)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedHome = home
            }
        } else if let home = annotation.home, bookmarkedHomeIds.contains(home.id) {
            // Saved/Bookmarked homes - red heart
            VStack(spacing: 0) {
                // Price tag
                if let price = home.price {
                    Text("$\(formatPrice(price))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .cornerRadius(8)
                }

                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(.red)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    )
                    .shadow(radius: 2)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedHome = home
            }
        } else {
            // Property pin - purple for rentals, orange for sales
            VStack(spacing: 0) {
                // Price tag
                if let home = annotation.home, let price = home.price {
                    let isRental = home.listingType?.lowercased() == "rental" || home.listingType == "For Rent"
                    Text("$\(formatPrice(price))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isRental ? Color.purple : Color.orange)
                        .cornerRadius(8)
                }

                // Pin
                if let home = annotation.home {
                    let isRental = home.listingType?.lowercased() == "rental" || home.listingType == "For Rent"
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(isRental ? .purple : .orange)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let home = annotation.home {
                    selectedHome = home
                }
            }
        }
    }

    var mapAnnotations: [PropertyMapAnnotation] {
        var annotations: [PropertyMapAnnotation] = []

        // Add user location if available
        if let userLocation = userLocation {
            annotations.append(PropertyMapAnnotation(
                id: UUID(),
                coordinate: userLocation,
                isUserLocation: true,
                home: nil
            ))
        }

        // Add property pins
        for home in homes {
            // Check if we have a geocoded coordinate first
            if let geocodedCoordinate = geocodedCoordinates[home.id] {
                annotations.append(PropertyMapAnnotation(
                    id: home.id,
                    coordinate: geocodedCoordinate,
                    isUserLocation: false,
                    home: home
                ))
            } else if let coordinate = getCoordinate(for: home) {
                // Fallback to city/state database
                annotations.append(PropertyMapAnnotation(
                    id: home.id,
                    coordinate: coordinate,
                    isUserLocation: false,
                    home: home
                ))
            }
        }

        return annotations
    }

    func geocodeAllHomes() {
        // Prioritize highlighted home first - ALWAYS re-geocode to ensure accuracy
        if let highlightedId = highlightedHomeId,
           let highlightedHome = homes.first(where: { $0.id == highlightedId }) {
            print("🎯 Prioritizing geocoding for highlighted home...")
            // Clear cached coordinate to force fresh geocode
            geocodedCoordinates.removeValue(forKey: highlightedId)
            geocodeHome(highlightedHome, priority: true)
        }

        guard !isGeocoding else { return }
        isGeocoding = true

        for home in homes {
            // Skip if already geocoded or currently being prioritized
            guard geocodedCoordinates[home.id] == nil else { continue }

            geocodeHome(home, priority: false)
        }

        isGeocoding = false
    }

    func geocodeHome(_ home: Home, priority: Bool) {
        print("🔍 geocodeHome called for: \(home.city ?? "?"), \(home.state ?? "?") - Address: \(home.address ?? "?")")

        // For priority (highlighted) homes, use city/state fallback IMMEDIATELY for fast display
        // Then try full geocoding in background for accuracy
        if priority, let fallbackCoordinate = getCoordinate(for: home) {
            print("⚡ Using immediate fallback coordinate for fast display")
            DispatchQueue.main.async {
                self.geocodedCoordinates[home.id] = fallbackCoordinate
                self.updateRegion()
                // Turn off loading after map positions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.isLoadingHighlightedHome = false
                }
            }
        }

        // Build full address string
        var addressComponents: [String] = []
        if let address = home.address, !address.isEmpty {
            addressComponents.append(address)
        }
        if let city = home.city, !city.isEmpty {
            addressComponents.append(city)
        }
        if let state = home.state, !state.isEmpty {
            addressComponents.append(state)
        }
        if let zipCode = home.zipCode, !zipCode.isEmpty {
            addressComponents.append(zipCode)
        }

        guard !addressComponents.isEmpty else {
            print("⚠️ No address components for home \(home.id)")
            if priority && !geocodedCoordinates.keys.contains(home.id) {
                print("❌ No coordinate available for highlighted home")
                DispatchQueue.main.async {
                    self.isLoadingHighlightedHome = false
                }
            }
            return
        }

        let fullAddress = addressComponents.joined(separator: ", ")

        // Geocode the address for precision (this happens in background)
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(fullAddress) { [home, self] placemarks, error in
            if let error = error {
                print("⚠️ Geocoding failed for '\(fullAddress)': \(error.localizedDescription)")
                // Fallback to city/state database for non-priority homes
                if !priority, let fallbackCoordinate = self.getCoordinate(for: home) {
                    print("📍 Using city/state fallback: \(home.city ?? "?"), \(home.state ?? "?")")
                    DispatchQueue.main.async {
                        self.geocodedCoordinates[home.id] = fallbackCoordinate
                    }
                }
                return
            }

            if let location = placemarks?.first?.location {
                DispatchQueue.main.async {
                    let oldCoordinate = self.geocodedCoordinates[home.id]
                    self.geocodedCoordinates[home.id] = location.coordinate

                    if priority {
                        print("✅ 🎯 PRECISION Geocoded: \(fullAddress) -> \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        // Only update region if this is more precise than fallback
                        if oldCoordinate == nil || self.distance(from: oldCoordinate!, to: location.coordinate) > 100 {
                            print("📍 Refining map position with precise coordinate")
                            self.updateRegion()
                        }
                    } else {
                        print("✅ Geocoded: \(fullAddress) -> \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    }
                }
            }
        }
    }

    func distance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return loc1.distance(from: loc2) // Returns meters
    }

    func updateRegion() {
        // Priority #1: Center on highlighted home if specified (from pin drop button)
        if let highlightedId = highlightedHomeId,
           let highlightedHome = homes.first(where: { $0.id == highlightedId }) {
            // Try geocoded coordinate first (most accurate), then fallback to city/state database
            let coordinate = geocodedCoordinates[highlightedId] ?? getCoordinate(for: highlightedHome)

            if let coordinate = coordinate {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // Zoom in close
                    ))
                }
                print("📍 Map centered on highlighted home: \(highlightedHome.address ?? "unknown address")")

                // Turn off loading indicator after map animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.isLoadingHighlightedHome = false
                }
            } else {
                print("⚠️ No coordinate found for highlighted home \(highlightedId)")
                // No coordinate available, turn off loading
                isLoadingHighlightedHome = false
            }
        }
        // Priority #2: Center on user location if available
        else if let userLocation = userLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2) // Show ~20 mile radius
            ))
            print("📍 Map centered on user location: \(userLocation.latitude), \(userLocation.longitude)")
        }
        // Priority #3: If we have homes, center on first home
        else if let firstHome = homes.first, let coordinate = getCoordinate(for: firstHome) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            ))
            print("📍 Map centered on first home: \(firstHome.city ?? "unknown city")")
        }
        // Otherwise keep showing Orlando, FL
        else {
            print("📍 Map showing Orlando, FL (default - no user location or homes yet)")
        }
    }

    func getCoordinate(for home: Home) -> CLLocationCoordinate2D? {
        guard let city = home.city, let state = home.state else { return nil }

        // Clean up city and state names
        let cleanCity = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanState = state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Try exact match first
        let cityKey = "\(cleanCity),\(cleanState)"
        if let coordinate = USCityCoordinates.coordinates[cityKey] {
            print("✅ Found coordinate for '\(city), \(state)' using key '\(cityKey)'")
            return coordinate
        } else {
            print("❌ No coordinate found for '\(city), \(state)' (key: '\(cityKey)')")
        }

        // Try partial match (in case of "Miami Beach" vs "Miami")
        for (key, coordinate) in USCityCoordinates.coordinates {
            let keyComponents = key.split(separator: ",")
            if keyComponents.count == 2 {
                let dictCity = String(keyComponents[0])
                let dictState = String(keyComponents[1])

                // Check if the property city contains the dictionary city or vice versa
                if cleanState == dictState && (cleanCity.contains(dictCity) || dictCity.contains(cleanCity)) {
                    return coordinate
                }
            }
        }

        // Fallback to state center if city not found
        if let stateCenter = USStateCoordinates.coordinates[cleanState] {
            return stateCenter
        }

        return nil
    }

    func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let nsDecimal = NSDecimalNumber(decimal: price)
        let value = formatter.string(from: nsDecimal) ?? "\(price)"

        // Abbreviate large numbers
        let intValue = nsDecimal.intValue
        if intValue >= 1_000_000 {
            return String(format: "%.1fM", Double(intValue) / 1_000_000.0)
        } else if intValue >= 1_000 {
            return String(format: "%.0fK", Double(intValue) / 1_000.0)
        }
        return value
    }
}

struct PropertyMapAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let isUserLocation: Bool
    let home: Home?
}

// MARK: - US City Coordinates Database
struct USCityCoordinates {
    static let coordinates: [String: CLLocationCoordinate2D] = [
        // Florida
        "miami,FL": CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918),
        "tampa,FL": CLLocationCoordinate2D(latitude: 27.9506, longitude: -82.4572),
        "orlando,FL": CLLocationCoordinate2D(latitude: 28.5383, longitude: -81.3792),
        "winter park,FL": CLLocationCoordinate2D(latitude: 28.6000, longitude: -81.3392),
        "kissimmee,FL": CLLocationCoordinate2D(latitude: 28.2920, longitude: -81.4076),
        "altamonte springs,FL": CLLocationCoordinate2D(latitude: 28.6611, longitude: -81.3656),
        "oviedo,FL": CLLocationCoordinate2D(latitude: 28.6700, longitude: -81.2081),
        "lake mary,FL": CLLocationCoordinate2D(latitude: 28.7589, longitude: -81.3178),
        "sanford,FL": CLLocationCoordinate2D(latitude: 28.8005, longitude: -81.2729),
        "apopka,FL": CLLocationCoordinate2D(latitude: 28.6934, longitude: -81.5322),
        "winter garden,FL": CLLocationCoordinate2D(latitude: 28.5653, longitude: -81.5861),
        "windermere,FL": CLLocationCoordinate2D(latitude: 28.4989, longitude: -81.5362),
        "maitland,FL": CLLocationCoordinate2D(latitude: 28.6278, longitude: -81.3631),
        "casselberry,FL": CLLocationCoordinate2D(latitude: 28.6778, longitude: -81.3278),
        "jacksonville,FL": CLLocationCoordinate2D(latitude: 30.3322, longitude: -81.6557),
        "fort lauderdale,FL": CLLocationCoordinate2D(latitude: 26.1224, longitude: -80.1373),

        // California
        "los angeles,CA": CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
        "san francisco,CA": CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        "san diego,CA": CLLocationCoordinate2D(latitude: 32.7157, longitude: -117.1611),
        "san jose,CA": CLLocationCoordinate2D(latitude: 37.3382, longitude: -121.8863),
        "sacramento,CA": CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),

        // New York
        "new york,NY": CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        "manhattan,NY": CLLocationCoordinate2D(latitude: 40.7831, longitude: -73.9712),
        "brooklyn,NY": CLLocationCoordinate2D(latitude: 40.6782, longitude: -73.9442),
        "queens,NY": CLLocationCoordinate2D(latitude: 40.7282, longitude: -73.7949),
        "bronx,NY": CLLocationCoordinate2D(latitude: 40.8448, longitude: -73.8648),
        "staten island,NY": CLLocationCoordinate2D(latitude: 40.5795, longitude: -74.1502),
        "yonkers,NY": CLLocationCoordinate2D(latitude: 40.9312, longitude: -73.8987),
        "rochester,NY": CLLocationCoordinate2D(latitude: 43.1566, longitude: -77.6088),
        "syracuse,NY": CLLocationCoordinate2D(latitude: 43.0481, longitude: -76.1474),
        "albany,NY": CLLocationCoordinate2D(latitude: 42.6526, longitude: -73.7562),
        "buffalo,NY": CLLocationCoordinate2D(latitude: 42.8864, longitude: -78.8784),

        // Texas
        "houston,TX": CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698),
        "dallas,TX": CLLocationCoordinate2D(latitude: 32.7767, longitude: -96.7970),
        "austin,TX": CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
        "san antonio,TX": CLLocationCoordinate2D(latitude: 29.4241, longitude: -98.4936),

        // Illinois
        "chicago,IL": CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),

        // Pennsylvania
        "philadelphia,PA": CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652),
        "pittsburgh,PA": CLLocationCoordinate2D(latitude: 40.4406, longitude: -79.9959),

        // Arizona
        "phoenix,AZ": CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740),

        // Georgia
        "atlanta,GA": CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),

        // North Carolina
        "charlotte,NC": CLLocationCoordinate2D(latitude: 35.2271, longitude: -80.8431),
        "raleigh,NC": CLLocationCoordinate2D(latitude: 35.7796, longitude: -78.6382),

        // Washington
        "seattle,WA": CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321),

        // Massachusetts
        "boston,MA": CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),

        // Colorado
        "denver,CO": CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),

        // Nevada
        "las vegas,NV": CLLocationCoordinate2D(latitude: 36.1699, longitude: -115.1398),

        // Tennessee
        "nashville,TN": CLLocationCoordinate2D(latitude: 36.1627, longitude: -86.7816),
        "memphis,TN": CLLocationCoordinate2D(latitude: 35.1495, longitude: -90.0490),

        // Oregon
        "portland,OR": CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784),

        // Oklahoma
        "oklahoma city,OK": CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),

        // Louisiana
        "new orleans,LA": CLLocationCoordinate2D(latitude: 29.9511, longitude: -90.0715),

        // Ohio
        "columbus,OH": CLLocationCoordinate2D(latitude: 39.9612, longitude: -82.9988),
        "cleveland,OH": CLLocationCoordinate2D(latitude: 41.4993, longitude: -81.6944),

        // Michigan
        "detroit,MI": CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458),

        // Minnesota
        "minneapolis,MN": CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650),

        // Missouri
        "kansas city,MO": CLLocationCoordinate2D(latitude: 39.0997, longitude: -94.5786),
        "st. louis,MO": CLLocationCoordinate2D(latitude: 38.6270, longitude: -90.1994),

        // Wisconsin
        "milwaukee,WI": CLLocationCoordinate2D(latitude: 43.0389, longitude: -87.9065),

        // Virginia
        "virginia beach,VA": CLLocationCoordinate2D(latitude: 36.8529, longitude: -75.9780),

        // Maryland
        "baltimore,MD": CLLocationCoordinate2D(latitude: 39.2904, longitude: -76.6122),
    ]
}

// MARK: - US State Center Coordinates
struct USStateCoordinates {
    static let coordinates: [String: CLLocationCoordinate2D] = [
        "AL": CLLocationCoordinate2D(latitude: 32.806671, longitude: -86.791130),
        "AK": CLLocationCoordinate2D(latitude: 61.370716, longitude: -152.404419),
        "AZ": CLLocationCoordinate2D(latitude: 33.729759, longitude: -111.431221),
        "AR": CLLocationCoordinate2D(latitude: 34.969704, longitude: -92.373123),
        "CA": CLLocationCoordinate2D(latitude: 36.116203, longitude: -119.681564),
        "CO": CLLocationCoordinate2D(latitude: 39.059811, longitude: -105.311104),
        "CT": CLLocationCoordinate2D(latitude: 41.597782, longitude: -72.755371),
        "DE": CLLocationCoordinate2D(latitude: 39.318523, longitude: -75.507141),
        "FL": CLLocationCoordinate2D(latitude: 27.766279, longitude: -81.686783),
        "GA": CLLocationCoordinate2D(latitude: 33.040619, longitude: -83.643074),
        "HI": CLLocationCoordinate2D(latitude: 21.094318, longitude: -157.498337),
        "ID": CLLocationCoordinate2D(latitude: 44.240459, longitude: -114.478828),
        "IL": CLLocationCoordinate2D(latitude: 40.349457, longitude: -88.986137),
        "IN": CLLocationCoordinate2D(latitude: 39.849426, longitude: -86.258278),
        "IA": CLLocationCoordinate2D(latitude: 42.011539, longitude: -93.210526),
        "KS": CLLocationCoordinate2D(latitude: 38.526600, longitude: -96.726486),
        "KY": CLLocationCoordinate2D(latitude: 37.668140, longitude: -84.670067),
        "LA": CLLocationCoordinate2D(latitude: 31.169546, longitude: -91.867805),
        "ME": CLLocationCoordinate2D(latitude: 44.693947, longitude: -69.381927),
        "MD": CLLocationCoordinate2D(latitude: 39.063946, longitude: -76.802101),
        "MA": CLLocationCoordinate2D(latitude: 42.230171, longitude: -71.530106),
        "MI": CLLocationCoordinate2D(latitude: 43.326618, longitude: -84.536095),
        "MN": CLLocationCoordinate2D(latitude: 45.694454, longitude: -93.900192),
        "MS": CLLocationCoordinate2D(latitude: 32.741646, longitude: -89.678696),
        "MO": CLLocationCoordinate2D(latitude: 38.456085, longitude: -92.288368),
        "MT": CLLocationCoordinate2D(latitude: 46.921925, longitude: -110.454353),
        "NE": CLLocationCoordinate2D(latitude: 41.125370, longitude: -98.268082),
        "NV": CLLocationCoordinate2D(latitude: 38.313515, longitude: -117.055374),
        "NH": CLLocationCoordinate2D(latitude: 43.452492, longitude: -71.563896),
        "NJ": CLLocationCoordinate2D(latitude: 40.298904, longitude: -74.521011),
        "NM": CLLocationCoordinate2D(latitude: 34.840515, longitude: -106.248482),
        "NY": CLLocationCoordinate2D(latitude: 42.165726, longitude: -74.948051),
        "NC": CLLocationCoordinate2D(latitude: 35.630066, longitude: -79.806419),
        "ND": CLLocationCoordinate2D(latitude: 47.528912, longitude: -99.784012),
        "OH": CLLocationCoordinate2D(latitude: 40.388783, longitude: -82.764915),
        "OK": CLLocationCoordinate2D(latitude: 35.565342, longitude: -96.928917),
        "OR": CLLocationCoordinate2D(latitude: 44.572021, longitude: -122.070938),
        "PA": CLLocationCoordinate2D(latitude: 40.590752, longitude: -77.209755),
        "RI": CLLocationCoordinate2D(latitude: 41.680893, longitude: -71.511780),
        "SC": CLLocationCoordinate2D(latitude: 33.856892, longitude: -80.945007),
        "SD": CLLocationCoordinate2D(latitude: 44.299782, longitude: -99.438828),
        "TN": CLLocationCoordinate2D(latitude: 35.747845, longitude: -86.692345),
        "TX": CLLocationCoordinate2D(latitude: 31.054487, longitude: -97.563461),
        "UT": CLLocationCoordinate2D(latitude: 40.150032, longitude: -111.862434),
        "VT": CLLocationCoordinate2D(latitude: 44.045876, longitude: -72.710686),
        "VA": CLLocationCoordinate2D(latitude: 37.769337, longitude: -78.169968),
        "WA": CLLocationCoordinate2D(latitude: 47.400902, longitude: -121.490494),
        "WV": CLLocationCoordinate2D(latitude: 38.491226, longitude: -80.954453),
        "WI": CLLocationCoordinate2D(latitude: 44.268543, longitude: -89.616508),
        "WY": CLLocationCoordinate2D(latitude: 42.755966, longitude: -107.302490),
    ]
}

// MARK: - Open House List View
struct OpenHouseListView: View {
    let homes: [Home]
    let userLocation: CLLocationCoordinate2D?
    let onSelectHome: (Home) -> Void
    let onDeleteHome: (Home) -> Void

    var body: some View {
        Group {
            if homes.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("No Saved Open Houses")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("Tap the green calendar button on Open House posts to save them here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List of open houses
                List {
                    ForEach(homes) { home in
                        Button(action: {
                            onSelectHome(home)
                        }) {
                            OpenHouseRowView(home: home, userLocation: userLocation)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDeleteHome(homes[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Open House Row View
struct OpenHouseRowView: View {
    let home: Home
    let userLocation: CLLocationCoordinate2D?
    @State private var geocodedDistance: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Address
            Text(home.address ?? "Address Not Available")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            // City, State
            if let city = home.city, let state = home.state {
                Text("\(city), \(state)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Date and Time
            if let startDate = home.openHouseDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(formatOpenHouseDateTime(start: startDate, end: home.openHouseEndDate))
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
            }

            HStack(spacing: 16) {
                // Distance
                if userLocation != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        if let distance = geocodedDistance {
                            Text(formatDistance(distance))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                        } else {
                            Text("Calculating...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if let userLoc = userLocation {
                geocodeAddress(userLocation: userLoc)
            }
        }
    }

    func formatOpenHouseDateTime(start: Date, end: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d" // "Mon, Nov 4"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dateString = dateFormatter.string(from: start)
        let startTime = timeFormatter.string(from: start)

        if let end = end {
            let endTime = timeFormatter.string(from: end)
            return "\(dateString) at \(startTime) - \(endTime)"
        } else {
            let defaultEnd = start.addingTimeInterval(7200)
            let endTime = timeFormatter.string(from: defaultEnd)
            return "\(dateString) at \(startTime) - \(endTime)"
        }
    }

    func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance)) meters"
        } else {
            let miles = distance / 1609.34 // Convert meters to miles
            return String(format: "%.1f miles", miles)
        }
    }

    func geocodeAddress(userLocation: CLLocationCoordinate2D) {
        guard let address = home.address,
              let city = home.city,
              let state = home.state else {
            print("⚠️ Missing address components for geocoding")
            return
        }

        let fullAddress = "\(address), \(city), \(state)"
        print("📍 Geocoding address: \(fullAddress)")

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(fullAddress) { placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                // Fallback to city center if geocoding fails
                self.fallbackToCityDistance(userLocation: userLocation)
                return
            }

            if let placemark = placemarks?.first,
               let location = placemark.location {
                let homeLocation = location.coordinate
                let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                let propLoc = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
                let distance = userLoc.distance(from: propLoc)

                DispatchQueue.main.async {
                    self.geocodedDistance = distance
                    print("✅ Geocoded distance: \(String(format: "%.1f", distance / 1609.34)) miles")
                }
            } else {
                print("⚠️ No placemark found, using fallback")
                self.fallbackToCityDistance(userLocation: userLocation)
            }
        }
    }

    func fallbackToCityDistance(userLocation: CLLocationCoordinate2D) {
        guard let city = home.city, let state = home.state else {
            return
        }

        let cleanCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanState = state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Try city coordinates first
        let cityKey = "\(cleanCity),\(cleanState)"
        if let coordinate = USCityCoordinates.coordinates[cityKey] {
            let homeLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let distance = userLoc.distance(from: homeLocation)
            DispatchQueue.main.async {
                self.geocodedDistance = distance
            }
            return
        }

        // Fallback to state center
        if let stateCoord = USStateCoordinates.coordinates[cleanState] {
            let homeLocation = CLLocation(latitude: stateCoord.latitude, longitude: stateCoord.longitude)
            let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let distance = userLoc.distance(from: homeLocation)
            DispatchQueue.main.async {
                self.geocodedDistance = distance
            }
        }
    }
}

#Preview {
    LocationFeedView()
}

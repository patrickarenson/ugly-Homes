//
//  OnboardingView.swift
//  Ugly Homes
//
//  Onboarding flow to capture user information immediately after signup
//

import SwiftUI
import PhotosUI
import CoreLocation
import MapKit

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var username = ""
    @State private var location = ""
    @State private var selectedUserTypes: Set<String> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    // Buyer preferences
    @State private var selectedPriceRange: String = ""
    @State private var selectedBedrooms: Int = 0
    @State private var selectedBathrooms: Int = 0

    // Background import tracking
    @State private var hasTriggeredImport = false
    @State private var phase1PropertyIds: [[String: String]] = [] // Store for Phase 2 backfill

    let userId: UUID
    let existingUsername: String

    let userTypeOptions = [
        ("realtor", "Realtor/Broker", "Licensed real estate agent"),
        ("professional", "Real Estate Professional", "Lender, appraiser, title, etc."),
        ("buyer", "Home Buyer", "Looking to purchase a home"),
        ("renter", "Renter", "Looking for my next rental"),
        ("investor", "Investor/Flipper", "Fix & flip, rentals, wholesaling"),
        ("designer", "Designer/Decorator", "Interior design or staging"),
        ("browsing", "Browsing", "Just exploring properties")
    ]

    var progress: Double {
        Double(currentStep) / 3.0
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.65, blue: 0.3),
                                        Color(red: 1.0, green: 0.45, blue: 0.2)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .frame(height: 4)

                Spacer()
                    .frame(height: 60) // Space for nav buttons

                // Content
                TabView(selection: $currentStep) {
                // Step 1: Welcome
                WelcomeStep()
                    .tag(0)

                // Step 2: User Type & Location
                UserTypeLocationStep(
                    selectedUserTypes: $selectedUserTypes,
                    location: $location,
                    username: existingUsername,
                    userTypeOptions: userTypeOptions,
                    selectedPriceRange: $selectedPriceRange,
                    selectedBedrooms: $selectedBedrooms,
                    selectedBathrooms: $selectedBathrooms
                )
                .tag(1)

                // Step 3: Profile Photo
                PhotoStep(selectedPhoto: $selectedPhoto, profileImage: $profileImage)
                    .tag(2)

                // Step 4: Ready to go
                ReadyStep()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .gesture(DragGesture().onChanged({ _ in })) // Disable swipe, but allow taps

            // Bottom navigation button
            VStack(spacing: 12) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: nextStep) {
                    Text(currentStep == 3 ? "Get Started" : currentStep == 0 ? "Continue" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.3),
                                    Color(red: 1.0, green: 0.45, blue: 0.2)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.3).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(isUploading)
                .opacity(isUploading ? 0.6 : 1.0)
            }
            .padding()
        }

            // Top navigation buttons
            VStack {
                HStack {
                    // Back button - top left
                    if currentStep > 0 && currentStep < 3 {
                        Button(action: { currentStep -= 1 }) {
                            Text("Back")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    } else {
                        Spacer()
                            .frame(width: 80)
                    }

                    Spacer()

                    // Skip button - top right (hide on first page)
                    if currentStep > 0 && currentStep < 3 {
                        Button(action: nextStep) {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    profileImage = image
                }
            }
        }
    }

    func nextStep() {
        if currentStep < 3 {
            // Trigger Phase 1 import when leaving Step 1 (User Type & Location)
            if currentStep == 1 && !hasTriggeredImport && !location.isEmpty {
                hasTriggeredImport = true
                triggerPhase1Import()
            }

            withAnimation {
                currentStep += 1
            }
        } else {
            // Final step - save everything and trigger Phase 2
            completeOnboarding()
        }
    }

    /// Get primary user type for import
    private func getPrimaryUserType() -> String {
        if selectedUserTypes.contains("buyer") {
            return "buyer"
        } else if selectedUserTypes.contains("renter") {
            return "renter"
        } else if selectedUserTypes.contains("investor") {
            return "investor"
        } else if selectedUserTypes.contains("realtor") {
            return "realtor"
        } else if selectedUserTypes.contains("professional") {
            return "professional"
        } else if selectedUserTypes.contains("designer") {
            return "designer"
        } else {
            return "browsing"
        }
    }

    /// Build preferences dictionary for buyer/renter
    private func buildPreferences(userType: String) -> [String: Any]? {
        guard userType == "buyer" || userType == "renter" else { return nil }

        var preferences: [String: Any] = [:]

        // Parse price range
        if !selectedPriceRange.isEmpty {
            if userType == "renter" {
                // Rental price ranges (monthly rent)
                let rentalPriceRanges: [String: (Int, Int)] = [
                    "under1500": (0, 1500),
                    "1500-2500": (1500, 2500),
                    "2500-3500": (2500, 3500),
                    "3500-5000": (3500, 5000),
                    "over5000": (5000, 20000)
                ]
                if let range = rentalPriceRanges[selectedPriceRange] {
                    preferences["minPrice"] = range.0
                    preferences["maxPrice"] = range.1
                }
            } else {
                // Purchase price ranges
                let priceRanges: [String: (Int, Int)] = [
                    "under200k": (0, 200000),
                    "200k-400k": (200000, 400000),
                    "400k-600k": (400000, 600000),
                    "600k-800k": (600000, 800000),
                    "800k-1m": (800000, 1000000),
                    "over1m": (1000000, 10000000)
                ]
                if let range = priceRanges[selectedPriceRange] {
                    preferences["minPrice"] = range.0
                    preferences["maxPrice"] = range.1
                }
            }
        }

        if selectedBedrooms > 0 {
            preferences["bedrooms"] = selectedBedrooms
        }
        if selectedBathrooms > 0 {
            preferences["bathrooms"] = selectedBathrooms
        }

        return preferences.isEmpty ? nil : preferences
    }

    /// Phase 1: Fast import of 10 properties (no descriptions) - runs while user continues onboarding
    /// On WiFi: Fetches full photos and descriptions for best experience
    /// On Cellular: Fast mode - basic data only, Phase 2 fills in later
    func triggerPhase1Import() {
        Task {
            let userType = getPrimaryUserType()
            let isOnWiFi = NetworkMonitor.shared.shouldFetchFullData

            // Build request body for Phase 1
            var body: [String: Any] = [
                "userType": userType,
                "location": location,
                "phase": 1,
                "fullPhotos": isOnWiFi // WiFi = fetch all photos and descriptions
            ]

            if let preferences = buildPreferences(userType: userType) {
                body["preferences"] = preferences
            }

            print("🌐 Network: \(isOnWiFi ? "WiFi - fetching full photos" : "Cellular - fast mode")")

            // Call the API
            guard let url = URL(string: "\(Config.apiBaseURL)/api/onboarding-import") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    print("🏠 Phase 1 import triggered: \(httpResponse.statusCode)")

                    // Parse response to get property IDs for Phase 2 backfill
                    if httpResponse.statusCode == 200,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let properties = json["properties"] as? [[String: Any]] {

                        // Extract id and zpid for each property
                        var propertyIds: [[String: String]] = []
                        for prop in properties {
                            if let id = prop["id"] as? String,
                               let zpid = prop["zpid"] as? String {
                                propertyIds.append(["id": id, "zpid": zpid])
                            }
                        }

                        await MainActor.run {
                            self.phase1PropertyIds = propertyIds
                        }

                        print("🏠 Phase 1 complete: \(properties.count) properties, stored \(propertyIds.count) IDs for Phase 2")
                    }
                }
            } catch {
                print("⚠️ Phase 1 import error: \(error.localizedDescription)")
                // Don't show error to user - this is background operation
            }
        }
    }

    /// Phase 2: Import remaining 15 properties + backfill descriptions for Phase 1 properties
    func triggerPhase2Import() {
        Task {
            let userType = getPrimaryUserType()

            // Build request body for Phase 2
            var body: [String: Any] = [
                "userType": userType,
                "location": location,
                "phase": 2
            ]

            if let preferences = buildPreferences(userType: userType) {
                body["preferences"] = preferences
            }

            // Include Phase 1 property IDs for description backfill
            if !phase1PropertyIds.isEmpty {
                body["propertyIds"] = phase1PropertyIds
            }

            // Call the API
            guard let url = URL(string: "\(Config.apiBaseURL)/api/onboarding-import") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    print("🏠 Phase 2 import complete: \(httpResponse.statusCode)")
                }
            } catch {
                print("⚠️ Phase 2 import error: \(error.localizedDescription)")
                // Don't show error to user - this is background operation
            }
        }
    }

    func skipOnboarding() {
        // Mark onboarding as complete without saving info
        UserDefaults.standard.set(true, forKey: "onboardingCompleted_\(userId.uuidString)")
        dismiss()
    }

    /// Convert technical errors to friendly, actionable messages
    func friendlyErrorMessage(from error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()

        // RLS/Permission errors (photo upload issues)
        if errorDescription.contains("row-level security") ||
           errorDescription.contains("rls") ||
           errorDescription.contains("policy") ||
           errorDescription.contains("permission") {
            return "Couldn't upload your photo. You can skip for now and add one later in settings."
        }

        // Network errors
        if errorDescription.contains("network") ||
           errorDescription.contains("internet") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("offline") ||
           errorDescription.contains("timeout") {
            return "Connection issue. Check your internet and try again."
        }

        // Auth errors
        if errorDescription.contains("session") ||
           errorDescription.contains("auth") ||
           errorDescription.contains("token") ||
           errorDescription.contains("unauthorized") {
            return "Session expired. Please sign in again."
        }

        // Storage/upload errors
        if errorDescription.contains("upload") ||
           errorDescription.contains("storage") ||
           errorDescription.contains("bucket") {
            return "Couldn't upload photo. Try again or skip for now."
        }

        // Default friendly message
        return "Something went wrong. Please try again or skip this step."
    }

    func completeOnboarding() {
        isUploading = true
        errorMessage = nil

        Task {
            do {
                // Upload profile photo if selected
                var avatarUrl: String? = nil
                if let image = profileImage {
                    avatarUrl = try await uploadProfilePhoto(image: image)
                }
                // If no photo selected, avatar_url will be nil and profile will use default

                // Update profile with user types, location, photo, and onboarding status
                struct ProfileUpdate: Encodable {
                    let market: String?
                    let avatar_url: String?
                    let user_types: [String]?
                    let has_completed_onboarding: Bool
                }

                let update = ProfileUpdate(
                    market: location.isEmpty ? nil : location,
                    avatar_url: avatarUrl,
                    user_types: selectedUserTypes.isEmpty ? nil : Array(selectedUserTypes),
                    has_completed_onboarding: true
                )

                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(update)
                    .eq("id", value: userId.uuidString)
                    .execute()

                print("✅ Profile updated via onboarding")
                print("✅ Onboarding marked complete in database for user: \(userId.uuidString)")

                // Trigger Phase 2 import in background (imports remaining 15 properties + descriptions)
                if hasTriggeredImport && !location.isEmpty {
                    triggerPhase2Import()
                }

                // Post notification to refresh profile
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    dismiss()
                }
            } catch {
                print("❌ Error completing onboarding: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = friendlyErrorMessage(from: error)
                    isUploading = false
                }
            }
        }
    }

    func uploadProfilePhoto(image: UIImage) async throws -> String {
        // Resize image to reasonable size
        let maxSize: CGFloat = 800
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let resizedImage = resizedImage,
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }

        // Upload to Supabase Storage
        let fileName = "\(userId.uuidString)_\(Date().timeIntervalSince1970).jpg"
        let filePath = try await SupabaseManager.shared.client.storage
            .from("Avatars")
            .upload(path: fileName, file: imageData, options: .init(contentType: "image/jpeg", upsert: true))

        // Get public URL
        let publicURL = try SupabaseManager.shared.client.storage
            .from("Avatars")
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    func generateDefaultAvatar(username: String) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Background - orange gradient
            let colors = [
                UIColor(red: 1.0, green: 0.65, blue: 0.3, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0.0, 1.0])!
            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])

            // First letter of username
            let firstLetter = String(username.prefix(1)).uppercased()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 100, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let textSize = (firstLetter as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            (firstLetter as NSString).draw(in: textRect, withAttributes: attributes)
        }

        return image
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))

            VStack(spacing: 12) {
                Text("Welcome to Houser!")
                    .font(.system(size: 32, weight: .bold))

                Text("Let's set up your profile to start sharing and discovering properties")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

// MARK: - Photo Step
struct PhotoStep: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var profileImage: UIImage?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Add a Profile Photo")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Help others recognize you")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(red: 1.0, green: 0.65, blue: 0.3), lineWidth: 3)
                        )
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                                Text("Tap to add")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }

            Spacer()
        }
    }
}

// MARK: - Location Search Completer for Autocomplete
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Filter to US only for better results
        let usRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )
        completer.region = usRegion
    }

    func search(_ query: String) {
        searchQuery = query
        if query.count >= 2 {
            isSearching = true
            completer.queryFragment = query
        } else {
            suggestions = []
            isSearching = false
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Filter to only show city/state results (not specific addresses)
        suggestions = completer.results.filter { result in
            // Include results that look like "City, State" format
            let hasComma = result.title.contains(",") || result.subtitle.contains(",")
            let isNotStreetAddress = !result.title.contains(where: { $0.isNumber })
            return hasComma || isNotStreetAddress
        }.prefix(5).map { $0 }
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
        print("Search completer error: \(error.localizedDescription)")
    }

    func formatLocation(_ completion: MKLocalSearchCompletion) -> String {
        if !completion.subtitle.isEmpty {
            return "\(completion.title), \(completion.subtitle)"
        }
        return completion.title
    }
}

// MARK: - Location Manager for Current Location (Onboarding)
class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var locationString: String = ""
    @Published var isLoading: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        isLoading = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
        @unknown default:
            isLoading = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isLoading = false
            return
        }

        // Reverse geocode to get city, state
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""

                    if !city.isEmpty && !state.isEmpty {
                        self?.locationString = "\(city), \(state)"
                    } else if !city.isEmpty {
                        self?.locationString = city
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - User Type & Location Step
struct UserTypeLocationStep: View {
    @Binding var selectedUserTypes: Set<String>
    @Binding var location: String
    let username: String
    let userTypeOptions: [(String, String, String)]

    // Buyer/Renter preferences
    @Binding var selectedPriceRange: String
    @Binding var selectedBedrooms: Int
    @Binding var selectedBathrooms: Int

    // Location manager and search
    @StateObject private var locationManager = OnboardingLocationManager()
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var locationInput = ""
    @State private var showSuggestions = false
    @FocusState private var isLocationFocused: Bool

    let buyerPriceRangeOptions = [
        ("under200k", "Under $200K"),
        ("200k-400k", "$200K - $400K"),
        ("400k-600k", "$400K - $600K"),
        ("600k-800k", "$600K - $800K"),
        ("800k-1m", "$800K - $1M"),
        ("over1m", "$1M+")
    ]

    let renterPriceRangeOptions = [
        ("under1500", "Under $1,500/mo"),
        ("1500-2500", "$1,500 - $2,500/mo"),
        ("2500-3500", "$2,500 - $3,500/mo"),
        ("3500-5000", "$3,500 - $5,000/mo"),
        ("over5000", "$5,000+/mo")
    ]

    var showBuyerPreferences: Bool {
        selectedUserTypes.contains("buyer")
    }

    var showRenterPreferences: Bool {
        selectedUserTypes.contains("renter")
    }

    var currentPriceRangeOptions: [(String, String)] {
        if showRenterPreferences && !showBuyerPreferences {
            return renterPriceRangeOptions
        }
        return buyerPriceRangeOptions
    }

    var preferencesTitle: String {
        if showBuyerPreferences && showRenterPreferences {
            return "Your Home Preferences"
        } else if showRenterPreferences {
            return "Your Rental Preferences"
        }
        return "Your Home Preferences"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Tell us about yourself")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This helps us personalize your experience")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)

                VStack(spacing: 20) {
                    // Username display (read-only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text("@\(username)")
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }

                    // User Type (multi-select)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What brings you to Houser?")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text("Select all that apply")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))

                        VStack(spacing: 10) {
                            ForEach(userTypeOptions, id: \.0) { option in
                                UserTypeButton(
                                    id: option.0,
                                    label: option.1,
                                    description: option.2,
                                    isSelected: selectedUserTypes.contains(option.0)
                                ) {
                                    if selectedUserTypes.contains(option.0) {
                                        selectedUserTypes.remove(option.0)
                                    } else {
                                        selectedUserTypes.insert(option.0)
                                    }
                                }
                            }
                        }
                    }

                    // Buyer/Renter Preferences (shown inline when "buyer" or "renter" is selected)
                    if showBuyerPreferences || showRenterPreferences {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(preferencesTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.25))

                            // Price Range
                            VStack(alignment: .leading, spacing: 8) {
                                Text(showRenterPreferences && !showBuyerPreferences ? "Monthly Rent" : "Price Range")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(currentPriceRangeOptions, id: \.0) { option in
                                        Button(action: {
                                            selectedPriceRange = selectedPriceRange == option.0 ? "" : option.0
                                        }) {
                                            Text(option.1)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedPriceRange == option.0 ? .white : .primary)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity)
                                                .background(
                                                    selectedPriceRange == option.0 ?
                                                    Color(red: 1.0, green: 0.55, blue: 0.25) :
                                                    Color.gray.opacity(0.1)
                                                )
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Bedrooms
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bedrooms")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                HStack(spacing: 8) {
                                    ForEach([1, 2, 3, 4, 5], id: \.self) { num in
                                        Button(action: {
                                            selectedBedrooms = selectedBedrooms == num ? 0 : num
                                        }) {
                                            Text(num == 5 ? "5+" : "\(num)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedBedrooms == num ? .white : .primary)
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    selectedBedrooms == num ?
                                                    Color(red: 1.0, green: 0.55, blue: 0.25) :
                                                    Color.gray.opacity(0.1)
                                                )
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Bathrooms
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bathrooms")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                HStack(spacing: 8) {
                                    ForEach([1, 2, 3, 4], id: \.self) { num in
                                        Button(action: {
                                            selectedBathrooms = selectedBathrooms == num ? 0 : num
                                        }) {
                                            Text(num == 4 ? "4+" : "\(num)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedBathrooms == num ? .white : .primary)
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    selectedBathrooms == num ?
                                                    Color(red: 1.0, green: 0.55, blue: 0.25) :
                                                    Color.gray.opacity(0.1)
                                                )
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(red: 1.0, green: 0.55, blue: 0.25).opacity(0.08))
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.3), value: showBuyerPreferences || showRenterPreferences)
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        // Use Current Location button
                        Button(action: {
                            locationManager.requestLocation()
                        }) {
                            HStack(spacing: 10) {
                                if locationManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                }
                                Text(locationManager.isLoading ? "Getting location..." : "Use Current Location")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.3, green: 0.6, blue: 1.0),
                                        Color(red: 0.2, green: 0.5, blue: 0.9)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                        }
                        .disabled(locationManager.isLoading)

                        // Show denial message if location denied
                        if locationManager.authorizationStatus == .denied {
                            Text("Location access denied. Please enable in Settings or type your location below.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        // Divider with "or"
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        // Location text field with autocomplete
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Type your city, e.g. Orlando, FL", text: $locationInput)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(showSuggestions && !searchCompleter.suggestions.isEmpty ? 0 : 10)
                                .cornerRadius(10, corners: showSuggestions && !searchCompleter.suggestions.isEmpty ? [.topLeft, .topRight] : [.topLeft, .topRight, .bottomLeft, .bottomRight])
                                .focused($isLocationFocused)
                                .onChange(of: locationInput) { _, newValue in
                                    searchCompleter.search(newValue)
                                    showSuggestions = true
                                }
                                .onSubmit {
                                    // If they press enter, use what they typed
                                    location = locationInput
                                    showSuggestions = false
                                }

                            // Autocomplete suggestions dropdown
                            if showSuggestions && !searchCompleter.suggestions.isEmpty && isLocationFocused {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(searchCompleter.suggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            let formatted = searchCompleter.formatLocation(suggestion)
                                            locationInput = formatted
                                            location = formatted
                                            showSuggestions = false
                                            isLocationFocused = false
                                        }) {
                                            HStack {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.25))
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(suggestion.title)
                                                        .font(.subheadline)
                                                        .foregroundColor(.primary)
                                                    if !suggestion.subtitle.isEmpty {
                                                        Text(suggestion.subtitle)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)

                                        if suggestion != searchCompleter.suggestions.last {
                                            Divider()
                                                .padding(.leading, 40)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)

                // Extra space at bottom for scrolling
                Spacer().frame(height: 100)
            }
        }
        .onChange(of: locationManager.locationString) { _, newValue in
            if !newValue.isEmpty {
                location = newValue
                locationInput = newValue
                showSuggestions = false
            }
        }
        .onTapGesture {
            // Dismiss suggestions when tapping outside
            if showSuggestions {
                showSuggestions = false
                isLocationFocused = false
            }
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - User Type Button
struct UserTypeButton: View {
    let id: String
    let label: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .gray)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.5))
            }
            .padding()
            .background(
                isSelected ?
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.3),
                            Color(red: 1.0, green: 0.45, blue: 0.2)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.1)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ready Step
struct ReadyStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold))

                Text("Start sharing properties and connecting with the community")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "house.circle.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Explore Listings")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Find homes with real feedback")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share Instantly")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Post any Zillow link in seconds")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "hammer.circle.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Showcase Projects")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Share renovations & design ideas")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(userId: UUID(), existingUsername: "johndoe")
}

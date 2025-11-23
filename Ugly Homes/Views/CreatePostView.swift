//
//  CreatePostView.swift
//  Ugly Homes
//
//  Create Post View
//

import SwiftUI
import PhotosUI
import UIKit

// Struct to hold comprehensive property data from API import
struct ComprehensivePropertyData {
    let schoolDistrict: String?
    let elementarySchool: String?
    let middleSchool: String?
    let highSchool: String?
    let schoolRating: Double?
    let hoaFee: Double?
    let lotSizeSqft: Int?
    let livingAreaSqft: Int?
    let yearBuilt: Int?
    let propertyTypeDetail: String?
    let parkingSpaces: Int?
    let stories: Int?
    let heatingType: String?
    let coolingType: String?
    let appliancesIncluded: [String]?
    let additionalDetails: [String: AnyCodable]?
}

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss

    let editingHome: Home?

    @State private var postType: PostType = .listing
    @State private var listingURL = ""
    @State private var listingType: ListingType = .sale
    @State private var description = ""
    @State private var price = ""
    @State private var bedrooms = ""
    @State private var bathrooms = ""
    @State private var squareFootage = ""
    @State private var address = ""
    @State private var unit = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var hideLocation = false

    // Comprehensive property data (from API import)
    @State private var comprehensiveData: ComprehensivePropertyData?

    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var imageData: [Data] = []
    @State private var imageUrls: [String] = []
    @State private var isUploading = false
    @State private var isImporting = false
    @State private var errorMessage = ""
    @State private var uploadProgress: String = ""

    // Open House feature
    @State private var enableOpenHouse = false
    @State private var openHouseDate = Date().addingTimeInterval(86400) // Default tomorrow
    @State private var openHouseEndDate = Date().addingTimeInterval(86400 + 21600) // Default +6 hours
    @State private var hasOpenHousePaid = false
    @State private var stripePaymentId: String?
    @State private var showPaymentSheet = false
    @State private var isProcessingPayment = false
    @State private var showCancelOpenHouseAlert = false

    enum PostType: String, CaseIterable {
        case listing = "🏠 Property"
        case project = "🔨 Home Project"
    }

    enum ListingType: String, CaseIterable {
        case sale = "For Sale"
        case rental = "For Rent"
    }

    init(editingHome: Home? = nil) {
        self.editingHome = editingHome

        // Pre-populate fields if editing
        if let home = editingHome {
            // Use the post_type from the database
            // Infer post type from database
            print("🔍 EDIT MODE DEBUG:")
            print("   - postType from DB: \(home.postType ?? "nil")")

            let inferredType: PostType
            // Use post_type from database
            if home.postType == "project" {
                inferredType = .project
            } else {
                inferredType = .listing
            }

            print("   - Inferred postType: \(inferredType)")
            _postType = State(initialValue: inferredType)
            _listingType = State(initialValue: home.listingType == "rental" ? .rental : .sale)
            _description = State(initialValue: home.description ?? "")
            _price = State(initialValue: home.price?.description ?? "")
            _bedrooms = State(initialValue: home.bedrooms != nil ? String(home.bedrooms!) : "")
            _bathrooms = State(initialValue: home.bathrooms != nil ? String(NSDecimalNumber(decimal: home.bathrooms!).doubleValue) : "")
            _squareFootage = State(initialValue: home.livingAreaSqft != nil ? String(home.livingAreaSqft!) : "")
            _address = State(initialValue: home.address ?? "")
            _unit = State(initialValue: home.unit ?? "")
            _city = State(initialValue: home.city ?? "")
            _state = State(initialValue: home.state ?? "")
            _zipCode = State(initialValue: home.zipCode ?? "")
            _imageUrls = State(initialValue: home.imageUrls)

            // Pre-populate open house fields if editing existing open house
            if home.openHousePaid == true, let openHouseStart = home.openHouseDate {
                _enableOpenHouse = State(initialValue: true)
                _hasOpenHousePaid = State(initialValue: true)
                _openHouseDate = State(initialValue: openHouseStart)
                _openHouseEndDate = State(initialValue: home.openHouseEndDate ?? openHouseStart.addingTimeInterval(7200))
                _stripePaymentId = State(initialValue: home.stripePaymentId)
            }
        }
    }

    // Form validation - all fields mandatory except location (unless hideLocation is false)
    var isFormValid: Bool {
        let hasPhotos = !imageData.isEmpty || !imageUrls.isEmpty
        let hasDescription = !description.isEmpty

        if postType == .project {
            // Projects only need: photos, description, city, state
            let hasLocation = !city.isEmpty && !state.isEmpty
            return hasPhotos && hasDescription && hasLocation
        } else {
            // Listings need: photos, description, price, bedrooms, bathrooms, address (unless hidden)
            let hasPrice = !price.isEmpty
            let hasBedrooms = !bedrooms.isEmpty
            let hasBathrooms = !bathrooms.isEmpty

            // If location is not hidden, address is required
            let locationValid = hideLocation || !address.isEmpty

            return hasPhotos && hasDescription && hasPrice && hasBedrooms && hasBathrooms && locationValid
        }
    }

    // MARK: - Photo Pair Management

    // Total number of photos (both uploaded and new)
    var totalPhotoCount: Int {
        return imageUrls.count + imageData.count
    }

    // Check if two indices form a pair
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Post Type Picker
                    VStack(alignment: .leading, spacing: 12) {
                        // Centered toggle buttons
                        Picker("Post Type", selection: $postType) {
                            ForEach(PostType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .disabled(editingHome != nil) // Disable when editing (can't change post type)
                        .opacity(editingHome != nil ? 0.6 : 1.0) // Show it's disabled
                    }

                    // Quick Import from Zillow (only for listings)
                    if editingHome == nil && postType == .listing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Import")
                                .font(.system(size: 15, weight: .medium))
                            Text("Zillow URL auto-fills your details.")
                                .font(.caption)
                                .foregroundColor(.gray)

                            HStack {
                                TextField("Paste Zillow URL here", text: $listingURL)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                Button(action: importFromURL) {
                                    if isImporting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .disabled(listingURL.isEmpty || isImporting)
                            }

                            // Import status/error message
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(errorMessage.contains("✅") ? .green : .orange)
                                    .font(.caption)
                                    .padding(.top, 4)
                            }

                            if isImporting {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("Importing listing data...")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }

                        Divider()
                    }

                    // Listing Type Picker (only for listings)
                    if postType == .listing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Listing Type")
                                .font(.system(size: 15, weight: .medium))
                            Picker("Type", selection: $listingType) {
                                ForEach(ListingType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    // Image picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(postType == .project ? "Before and After Photos" : "Photos")
                            .font(.system(size: 15, weight: .medium))
                        Text(postType == .project ? "Upload in pairs: before, after, before, after. Tap arrows to unpair." : "Tap to upload listing photos (up to 15)")
                            .font(.caption)
                            .foregroundColor(.gray)

                        // Photo preview and picker
                        VStack(alignment: .leading, spacing: 8) {
                            if imageUrls.isEmpty && imageData.isEmpty {
                                PhotosPicker(
                                    selection: $selectedImages,
                                    maxSelectionCount: 15,
                                    matching: .images
                                ) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 200)
                                        .overlay(
                                            VStack {
                                                Image(systemName: "photo.on.rectangle.angled")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(.gray)
                                                Text("Tap to select photos")
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                }
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        // Iterate through all photos and show arrows between consecutive pairs for projects
                                        ForEach(0..<totalPhotoCount, id: \.self) { photoIndex in
                                            // Show the photo
                                            ZStack {
                                                // Display either URL or Data image based on index
                                                if photoIndex < imageUrls.count {
                                                    // Show URL image
                                                    AsyncImage(url: URL(string: imageUrls[photoIndex])) { image in
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 150, height: 150)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    } placeholder: {
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.gray.opacity(0.2))
                                                            .frame(width: 150, height: 150)
                                                            .overlay(ProgressView())
                                                    }
                                                } else {
                                                    // Show Data image
                                                    let dataIndex = photoIndex - imageUrls.count
                                                    if let uiImage = UIImage(data: imageData[dataIndex]) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 150, height: 150)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    }
                                                }

                                                // Delete button (top-right)
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        Button(action: {
                                                            if photoIndex < imageUrls.count {
                                                                imageUrls.remove(at: photoIndex)
                                                            } else {
                                                                let dataIndex = photoIndex - imageUrls.count
                                                                imageData.remove(at: dataIndex)
                                                                selectedImages.remove(at: dataIndex)
                                                            }
                                                        }) {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .foregroundColor(.white)
                                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                                                .font(.title3)
                                                        }
                                                        .padding(8)
                                                    }
                                                    Spacer()
                                                }

                                                // Photo number badge and reorder controls
                                                VStack {
                                                    Spacer()
                                                    HStack(spacing: 4) {
                                                        // Move left button
                                                        if photoIndex > 0 {
                                                            Button(action: {
                                                                if photoIndex < imageUrls.count && photoIndex - 1 < imageUrls.count {
                                                                    imageUrls.swapAt(photoIndex, photoIndex - 1)
                                                                } else if photoIndex >= imageUrls.count {
                                                                    let dataIndex = photoIndex - imageUrls.count
                                                                    if dataIndex > 0 {
                                                                        imageData.swapAt(dataIndex, dataIndex - 1)
                                                                        selectedImages.swapAt(dataIndex, dataIndex - 1)
                                                                    }
                                                                }
                                                            }) {
                                                                Image(systemName: "chevron.left.circle.fill")
                                                                    .foregroundColor(.white)
                                                                    .background(Circle().fill(Color.orange.opacity(0.8)))
                                                                    .font(.title3)
                                                            }
                                                        }

                                                        Text("\(photoIndex + 1)")
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                            .padding(6)
                                                            .background(Circle().fill(Color.black.opacity(0.6)))

                                                        // Move right button
                                                        if photoIndex < totalPhotoCount - 1 {
                                                            Button(action: {
                                                                if photoIndex < imageUrls.count - 1 {
                                                                    imageUrls.swapAt(photoIndex, photoIndex + 1)
                                                                } else if photoIndex >= imageUrls.count {
                                                                    let dataIndex = photoIndex - imageUrls.count
                                                                    if dataIndex < imageData.count - 1 {
                                                                        imageData.swapAt(dataIndex, dataIndex + 1)
                                                                        selectedImages.swapAt(dataIndex, dataIndex + 1)
                                                                    }
                                                                }
                                                            }) {
                                                                Image(systemName: "chevron.right.circle.fill")
                                                                    .foregroundColor(.white)
                                                                    .background(Circle().fill(Color.orange.opacity(0.8)))
                                                                    .font(.title3)
                                                            }
                                                        }
                                                    }
                                                    .padding(8)
                                                }
                                            }
                                            .frame(width: 150, height: 150)
                                        }

                                        // Add more button (only show if less than 15 photos total)
                                        if totalPhotoCount < 15 {
                                            PhotosPicker(
                                                selection: $selectedImages,
                                                maxSelectionCount: 15,
                                                matching: .images
                                            ) {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 150, height: 150)
                                                    .overlay(
                                                        VStack {
                                                            Image(systemName: "plus")
                                                                .font(.system(size: 30))
                                                                .foregroundColor(.gray)
                                                            Text("Add more")
                                                                .font(.caption)
                                                                .foregroundColor(.gray)
                                                        }
                                                    )
                                            }
                                        }
                                    }
                                }
                                .frame(height: 150)

                                let totalPhotos = imageUrls.count + imageData.count
                                HStack {
                                    Text("\(totalPhotos) photo\(totalPhotos == 1 ? "" : "s") • Use arrows to reorder")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedImages) { oldItems, newItems in
                        Task {
                            imageData = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    imageData.append(data)
                                }
                            }
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(postType == .project ? "Project Story" : "Description")
                            .font(.system(size: 15, weight: .medium))
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            // Placeholder text
                            if description.isEmpty {
                                Text(postType == .project ? "Tell us what you're working on — mention your design style (modern farmhouse, coastal, industrial, etc.) to inspire others!" : "Highlight key features, upgrades, and neighborhood perks.")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    // Price (only for listings)
                    if postType == .listing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Price")
                                .font(.system(size: 15, weight: .medium))
                            TextField("$0", text: $price)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        // Bedrooms and Bathrooms
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bedrooms")
                                    .font(.system(size: 15, weight: .medium))
                                TextField("0", text: $bedrooms)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bathrooms")
                                    .font(.system(size: 15, weight: .medium))
                                TextField("0", text: $bathrooms)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }

                        // Square Footage
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Square Footage")
                                .font(.system(size: 15, weight: .medium))
                            TextField("0", text: $squareFootage)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.system(size: 15, weight: .medium))

                        if postType == .project {
                            // Projects only need city and state
                            HStack {
                                TextField("City", text: $city)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                TextField("State", text: $state)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .frame(maxWidth: 100)
                            }
                        } else {
                            // Listings show full address fields with hide location toggle
                            // Hide location toggle
                            HStack(spacing: 8) {
                                Button(action: {
                                    hideLocation.toggle()
                                    if hideLocation {
                                        // Clear location fields when hiding
                                        address = ""
                                        city = ""
                                        state = ""
                                        zipCode = ""
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: hideLocation ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(hideLocation ? .orange : .gray)
                                        Text("Hide location")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.bottom, 4)

                            // Only show address fields if location is not hidden
                            if !hideLocation {
                                TextField("Address", text: $address)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                TextField("Unit / Apt # (optional)", text: $unit)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                HStack {
                                    TextField("City", text: $city)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)

                                    TextField("State", text: $state)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .frame(maxWidth: 100)
                                }

                                TextField("Zip Code", text: $zipCode)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // MARK: - OPEN HOUSE SECTION (TEMPORARILY HIDDEN FOR APP STORE SUBMISSION)
                    // TODO: Uncomment this section when ready to re-enable Open House feature
                    /*
                    // Open House Section
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.vertical, 8)

                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.orange)
                            Text("Open House Feature")
                                .font(.headline)
                            Spacer()
                            // Only show price for new posts
                            if editingHome == nil {
                                Text("$5.99")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                        }

                        // Different description for editing vs creating
                        if editingHome != nil && hasOpenHousePaid {
                            Text("Edit your open house date and time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Add a gold 'OPEN HOUSE' badge to your listing with the date and time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Only show toggle for new posts or posts without open house
                        if editingHome == nil || !hasOpenHousePaid {
                            Toggle("Enable Open House", isOn: $enableOpenHouse)
                                .tint(.orange)
                        }

                        // Show date pickers if enabled OR if editing existing open house
                        if enableOpenHouse || (editingHome != nil && hasOpenHousePaid) {
                            VStack(alignment: .leading, spacing: 12) {
                                DatePicker("Start Date & Time", selection: $openHouseDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .onChange(of: openHouseDate) { oldValue, newValue in
                                        // Auto-adjust end date to be 6 hours later
                                        openHouseEndDate = newValue.addingTimeInterval(21600) // 6 hours
                                    }

                                DatePicker("End Date & Time", selection: $openHouseEndDate, in: openHouseDate...openHouseDate.addingTimeInterval(21600), displayedComponents: [.date, .hourAndMinute])

                                if !hasOpenHousePaid {
                                    Button(action: processOpenHousePayment) {
                                        HStack {
                                            if isProcessingPayment {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                Text("Processing...")
                                                    .fontWeight(.semibold)
                                            } else {
                                                Image(systemName: "creditcard.fill")
                                                Text("Pay $5.99 via Apple Pay")
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(isProcessingPayment ? Color.gray : Color.orange)
                                        .cornerRadius(10)
                                    }
                                    .disabled(isProcessingPayment)

                                    // Show error if payment fails
                                    if !errorMessage.isEmpty && (errorMessage.contains("Payment") || errorMessage.contains("Authentication") || errorMessage.contains("Error")) {
                                        Text(errorMessage)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.top, 4)
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Open House Paid - Badge will appear on your post!")
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)

                                        // Cancel Open House button
                                        Button(action: {
                                            showCancelOpenHouseAlert = true
                                        }) {
                                            HStack {
                                                Image(systemName: "xmark.circle.fill")
                                                Text("Cancel Open House")
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.red)
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    */

                    // Informational text before Post button
                    if editingHome == nil {
                        Text("Your post will appear on the Houser feed — get feedback, followers, and ideas from other real estate lovers.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    // Post button
                    Button(action: editingHome == nil ? createPost : updatePost) {
                        if isUploading {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                if !uploadProgress.isEmpty {
                                    Text(uploadProgress)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            Text(editingHome == nil ? "Post Property" : "Update Property")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(isFormValid ? Color.orange : Color.gray)
                    .cornerRadius(10)
                    .disabled(!isFormValid || isUploading)
                }
                .padding()
            }
            .navigationTitle(editingHome == nil ? "New Post" : (postType == .project ? "Edit Project" : "Edit Property"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Cancel Open House?", isPresented: $showCancelOpenHouseAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Cancel Open House", role: .destructive) {
                    cancelOpenHouse()
                }
            } message: {
                Text("This will notify all users who saved this open house. This action cannot be undone.")
            }
        }
    }

    // Validate if URL is from supported real estate sites
    func isValidListingURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("zillow.com") ||
               lowercased.contains("realtor.com") ||
               lowercased.contains("redfin.com") ||
               lowercased.contains("trulia.com")
    }

    func importFromURL() {
        print("⭐️ IMPORT BUTTON TAPPED - URL: \(listingURL)")
        guard !listingURL.isEmpty else {
            print("❌ URL is empty")
            return
        }

        // Validate URL format
        guard let url = URL(string: listingURL), url.scheme != nil else {
            print("❌ Invalid URL format")
            errorMessage = "⚠️ Please enter a valid URL"
            return
        }

        // Validate it's from Zillow
        guard listingURL.lowercased().contains("zillow.com") else {
            print("❌ Not a Zillow URL")
            errorMessage = "⚠️ Please use a Zillow URL"
            return
        }

        errorMessage = ""
        isImporting = true

        Task {
            // Retry logic: try up to 3 times
            var attempt = 0

            while attempt < 3 {
                do {
                    attempt += 1
                    if attempt > 1 {
                        print("🔄 Retry attempt \(attempt)/3...")
                        errorMessage = "Retrying... (attempt \(attempt)/3)"
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds between retries
                    }

                    print("🔄 Starting import from URL: \(listingURL)")

                    // Call the scraping API
                    let apiEndpoint = APIConfig.scrapingAPIEndpoint

                    guard let apiURL = URL(string: apiEndpoint) else {
                        throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Quick import unavailable - please fill form manually"])
                    }

                    var request = URLRequest(url: apiURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 30 // 30 second timeout

                    let body = ["url": listingURL]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    print("📡 Sending request to scraping API (attempt \(attempt))...")
                    print("🌐 API URL: \(apiEndpoint)")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    print("✅ Got response from API")

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Quick import unavailable"])
                    }

                    print("📥 Received response with status code: \(httpResponse.statusCode)")

                    if httpResponse.statusCode != 200 {
                        // Try to parse error message from response
                        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMsg = errorResponse["error"] as? String {
                            throw NSError(domain: "ImportError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                        } else {
                            throw NSError(domain: "ImportError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error \(httpResponse.statusCode)"])
                        }
                    }

                struct ScrapedListing: Codable {
                    let price: String?
                    let address: String?
                    let unit: String?
                    let city: String?
                    let state: String?
                    let zipCode: String?
                    let bedrooms: Int?
                    let bathrooms: Double?
                    let description: String?
                    let images: [String]?
                    let listingType: String?

                    // Comprehensive property data
                    let schoolDistrict: String?
                    let elementarySchool: String?
                    let middleSchool: String?
                    let highSchool: String?
                    let schoolRating: Double?
                    let hoaFee: Double?
                    let lotSizeSqft: Int?
                    let livingAreaSqft: Int?
                    let yearBuilt: Int?
                    let propertyTypeDetail: String?
                    let parkingSpaces: Int?
                    let stories: Int?
                    let heatingType: String?
                    let coolingType: String?
                    let appliancesIncluded: [String]?
                    let additionalDetails: [String: AnyCodable]?

                    enum CodingKeys: String, CodingKey {
                        case price
                        case address
                        case unit
                        case city
                        case state
                        case zipCode = "zip_code"
                        case bedrooms
                        case bathrooms
                        case description
                        case images
                        case listingType = "listing_type"
                        case schoolDistrict = "school_district"
                        case elementarySchool = "elementary_school"
                        case middleSchool = "middle_school"
                        case highSchool = "high_school"
                        case schoolRating = "school_rating"
                        case hoaFee = "hoa_fee"
                        case lotSizeSqft = "lot_size_sqft"
                        case livingAreaSqft = "living_area_sqft"
                        case yearBuilt = "year_built"
                        case propertyTypeDetail = "property_type_detail"
                        case parkingSpaces = "parking_spaces"
                        case stories
                        case heatingType = "heating_type"
                        case coolingType = "cooling_type"
                        case appliancesIncluded = "appliances_included"
                        case additionalDetails = "additional_details"
                    }
                }

                // Log raw JSON response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Raw API Response:")
                    print(jsonString)
                } else {
                    print("⚠️ Could not convert response data to string")
                }

                // Attempt to decode with detailed error handling
                let scraped: ScrapedListing
                do {
                    scraped = try JSONDecoder().decode(ScrapedListing.self, from: data)
                    print("✅ Successfully parsed listing data")
                } catch let DecodingError.keyNotFound(key, context) {
                    print("❌ Decoding Error - Key not found:")
                    print("  Missing key: \(key.stringValue)")
                    print("  Context: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing required field: \(key.stringValue)"])
                } catch let DecodingError.typeMismatch(type, context) {
                    print("❌ Decoding Error - Type mismatch:")
                    print("  Expected type: \(type)")
                    print("  Context: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Wrong data type at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"])
                } catch let DecodingError.valueNotFound(type, context) {
                    print("❌ Decoding Error - Value not found:")
                    print("  Expected type: \(type)")
                    print("  Context: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing value at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"])
                } catch let DecodingError.dataCorrupted(context) {
                    print("❌ Decoding Error - Data corrupted:")
                    print("  Context: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"])
                } catch {
                    print("❌ Unknown decoding error: \(error)")
                    print("  Error description: \(error.localizedDescription)")
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse property data: \(error.localizedDescription)"])
                }

                // Populate form fields
                var fieldsPopulated = 0

                if let price = scraped.price, !price.isEmpty {
                    self.price = price
                    fieldsPopulated += 1
                    print("💰 Price: $\(price)")
                }
                if let address = scraped.address, !address.isEmpty {
                    self.address = address
                    fieldsPopulated += 1
                    print("📍 Address: \(address)")
                }
                if let unit = scraped.unit, !unit.isEmpty {
                    self.unit = unit
                    fieldsPopulated += 1
                    print("🏢 Unit: \(unit)")
                }
                if let city = scraped.city, !city.isEmpty {
                    self.city = city
                    fieldsPopulated += 1
                }
                if let state = scraped.state, !state.isEmpty {
                    self.state = state
                    fieldsPopulated += 1
                }
                if let zipCode = scraped.zipCode, !zipCode.isEmpty {
                    self.zipCode = zipCode
                    fieldsPopulated += 1
                }
                if let beds = scraped.bedrooms {
                    self.bedrooms = String(beds)
                    fieldsPopulated += 1
                    print("🛏️ Bedrooms: \(beds)")
                }
                if let baths = scraped.bathrooms {
                    self.bathrooms = String(format: "%.1f", baths)
                    fieldsPopulated += 1
                    print("🚿 Bathrooms: \(baths)")
                }
                if let desc = scraped.description, !desc.isEmpty {
                    // Add source attribution for copyright compliance
                    self.description = desc + "\n\n📋 Listing data via Zillow"
                    fieldsPopulated += 1
                } else {
                    // Add attribution even if no description
                    self.description = "📋 Listing data via Zillow"
                }
                if let images = scraped.images, !images.isEmpty {
                    self.imageUrls = images
                    fieldsPopulated += 1
                    print("📷 Images: \(images.count) photos imported")
                    print("📷 First image URL: \(images.first ?? "none")")
                    print("📷 imageUrls array now has \(self.imageUrls.count) items")
                }
                if let type = scraped.listingType {
                    self.listingType = type == "rental" ? .rental : .sale
                    fieldsPopulated += 1
                    print("🏠 Listing type: \(type)")
                }
                if let sqft = scraped.livingAreaSqft {
                    self.squareFootage = String(sqft)
                    fieldsPopulated += 1
                    print("📐 Square footage: \(sqft)")
                }

                // Store comprehensive property data
                self.comprehensiveData = ComprehensivePropertyData(
                    schoolDistrict: scraped.schoolDistrict,
                    elementarySchool: scraped.elementarySchool,
                    middleSchool: scraped.middleSchool,
                    highSchool: scraped.highSchool,
                    schoolRating: scraped.schoolRating,
                    hoaFee: scraped.hoaFee,
                    lotSizeSqft: scraped.lotSizeSqft,
                    livingAreaSqft: scraped.livingAreaSqft,
                    yearBuilt: scraped.yearBuilt,
                    propertyTypeDetail: scraped.propertyTypeDetail,
                    parkingSpaces: scraped.parkingSpaces,
                    stories: scraped.stories,
                    heatingType: scraped.heatingType,
                    coolingType: scraped.coolingType,
                    appliancesIncluded: scraped.appliancesIncluded,
                    additionalDetails: scraped.additionalDetails
                )
                print("📊 Stored comprehensive property data")

                    // Success! Show results and break out of retry loop
                    isImporting = false

                    if fieldsPopulated > 0 {
                        errorMessage = "✅ Successfully imported \(fieldsPopulated) field(s)!"
                        print("✅ Successfully imported listing data - \(fieldsPopulated) fields populated")

                        // Clear success message after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            if self.errorMessage.contains("Successfully") {
                                self.errorMessage = ""
                            }
                        }
                    } else {
                        errorMessage = "⚠️ No data found - please fill out the form manually"
                        print("⚠️ No data was extracted from the listing")
                    }

                    return // Exit the Task - success!

                } catch let error as NSError {
                    print("⚠️ Import attempt \(attempt) failed: \(error.localizedDescription)")

                    // If this was the last attempt, show error
                    if attempt >= 3 {
                        isImporting = false

                        // Friendly error messages based on error type
                        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotConnectToHost {
                            errorMessage = "⚠️ Cannot connect to import server - please check your internet or fill form manually"
                        } else if error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
                            errorMessage = "⚠️ Import timed out - try again or fill form manually"
                        } else if error.localizedDescription.contains("unavailable") {
                            errorMessage = "⚠️ Import server is unavailable - please fill form manually"
                        } else {
                            errorMessage = "⚠️ Import failed - \(error.localizedDescription)"
                        }

                        print("❌ All retry attempts failed. User should fill form manually.")

                        // Auto-dismiss error after 6 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                            if self.errorMessage.contains("Import") || self.errorMessage.contains("failed") {
                                self.errorMessage = ""
                            }
                        }
                    }
                    // Otherwise, continue to next retry attempt
                }
            }
        }
    }

    func createPost() {
        print("🚀 createPost() called")
        print("   - Images: \(imageData.count) local, \(imageUrls.count) URLs")
        print("   - Description: \(description.isEmpty ? "EMPTY" : "✓")")
        print("   - Price: \(price.isEmpty ? "EMPTY" : price)")
        print("   - Bedrooms: \(bedrooms.isEmpty ? "EMPTY" : bedrooms)")
        print("   - Bathrooms: \(bathrooms.isEmpty ? "EMPTY" : bathrooms)")
        print("   - Square Footage: \(squareFootage.isEmpty ? "EMPTY" : squareFootage)")
        print("   - Address: \(address.isEmpty ? "EMPTY" : address)")

        errorMessage = ""
        isUploading = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("📤 Creating post for user: \(userId)")

                // CONTENT MODERATION - Check text content before proceeding
                print("🛡️ Running content moderation...")
                let titleToCheck = !address.isEmpty ? address : (!price.isEmpty ? "$\(price) \(listingType.rawValue)" : listingType.rawValue)
                let moderationResult = ContentModerationManager.shared.moderatePost(
                    title: titleToCheck,
                    description: description.isEmpty ? nil : description
                )

                var requiresReview = false
                var moderationReason: String? = nil

                switch moderationResult {
                case .blocked(let reason):
                    // Stop post creation - content is prohibited
                    await MainActor.run {
                        isUploading = false
                        errorMessage = reason
                    }
                    print("🚫 Post blocked: \(reason)")
                    return

                case .flaggedForReview(let reason, _):
                    // Allow post but flag for manual review
                    requiresReview = true
                    moderationReason = reason
                    print("⚠️ Post flagged for review: \(reason)")

                case .approved:
                    print("✅ Content approved")
                }

                // IMAGE VALIDATION - Check all images
                for (index, data) in imageData.enumerated() {
                    let validation = ContentModerationManager.shared.validateImage(data, filename: "image_\(index).jpg")
                    if !validation.isValid {
                        await MainActor.run {
                            isUploading = false
                            errorMessage = validation.error ?? "Invalid image"
                        }
                        print("🚫 Image validation failed: \(validation.error ?? "Unknown error")")
                        return
                    }
                }

                // Upload images to Supabase Storage (if manually selected)
                var finalImageUrls: [String] = imageUrls // Start with scraped URLs if any
                for (index, data) in imageData.enumerated() {
                    // Update progress on main thread
                    await MainActor.run {
                        uploadProgress = "Uploading image \(index + 1)/\(imageData.count)..."
                    }

                    // Compress image before upload
                    let compressedData: Data
                    if let image = UIImage(data: data) {
                        compressedData = compressImage(image) ?? data
                    } else {
                        compressedData = data
                    }

                    let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
                    print("📷 Uploading image \(index + 1)/\(imageData.count)")

                    try await SupabaseManager.shared.client.storage
                        .from("home-images")
                        .upload(fileName, data: compressedData, options: .init(contentType: "image/jpeg"))

                    let publicURL = try SupabaseManager.shared.client.storage
                        .from("home-images")
                        .getPublicURL(path: fileName)

                    finalImageUrls.append(publicURL.absoluteString)
                    print("✅ Image uploaded: \(publicURL.absoluteString)")
                }

                // Clear progress message
                await MainActor.run {
                    uploadProgress = ""
                }

                // Generate title from address or price (or city/state for projects)
                let generatedTitle: String
                if postType == .project {
                    // Projects use city, state as title
                    if !city.isEmpty && !state.isEmpty {
                        generatedTitle = "\(city), \(state)"
                    } else if !city.isEmpty {
                        generatedTitle = city
                    } else {
                        generatedTitle = "Project Showcase"
                    }
                } else {
                    // Listings use address or price
                    if !address.isEmpty {
                        generatedTitle = address
                    } else if !price.isEmpty {
                        generatedTitle = "$\(price) \(listingType.rawValue)"
                    } else if !city.isEmpty && !state.isEmpty {
                        generatedTitle = "\(city), \(state)"
                    } else {
                        generatedTitle = listingType.rawValue
                    }
                }

                // Generate hashtags
                var generatedTags: [String] = []

                if postType == .project {
                    // For projects, generate project-specific tags
                    generatedTags.append("#HomeProject")

                    // Add location tags
                    if !city.isEmpty {
                        generatedTags.append("#\(city.replacingOccurrences(of: " ", with: ""))")
                    }
                    if !state.isEmpty {
                        generatedTags.append("#\(state.replacingOccurrences(of: " ", with: ""))")
                    }

                    // Extract project keywords from description
                    let descriptionLower = description.lowercased()
                    let projectKeywords = [
                        ("renovation", "#Renovation"),
                        ("remodel", "#Remodel"),
                        ("flip", "#HouseFlip"),
                        ("diy", "#DIY"),
                        ("kitchen", "#KitchenReno"),
                        ("bathroom", "#BathroomReno"),
                        ("basement", "#BasementReno"),
                        ("exterior", "#ExteriorReno"),
                        ("landscaping", "#Landscaping"),
                        ("flooring", "#Flooring"),
                        ("paint", "#Painting"),
                        ("demo", "#Demolition"),
                        ("before and after", "#BeforeAndAfter"),
                        ("fixer", "#FixerUpper")
                    ]

                    for (keyword, tag) in projectKeywords {
                        if descriptionLower.contains(keyword) && !generatedTags.contains(tag) {
                            generatedTags.append(tag)
                        }
                    }
                } else {
                    // For listings, use existing tag generation
                    let priceDecimal: Decimal? = {
                        guard !price.isEmpty, let priceDouble = Double(price) else { return nil }
                        return Decimal(priceDouble)
                    }()

                    generatedTags = TagGenerator.generateTags(
                        city: city.isEmpty ? nil : city,
                        price: priceDecimal,
                        bedrooms: bedrooms.isEmpty ? nil : Int(bedrooms),
                        title: generatedTitle,
                        description: description.isEmpty ? nil : description,
                        listingType: listingType == .rental ? "rental" : "sale"
                    )

                    // Add invisible #OpenHouse tag for searchability
                    if enableOpenHouse && hasOpenHousePaid {
                        generatedTags.append("#OpenHouse")
                    }
                }

                print("🏷️ Generated tags: \(generatedTags)")

                // Create home post
                struct NewHome: Encodable {
                    let user_id: String
                    let title: String
                    let post_type: String
                    let listing_type: String?
                    let description: String?
                    let price: String?
                    let bedrooms: Int?
                    let bathrooms: String?
                    let address: String?
                    let unit: String?
                    let city: String?
                    let state: String?
                    let zip_code: String?
                    let image_urls: [String]
                    let before_photos: [String]?
                    let photo_pairs: [[Int]]?
                    let tags: [String]
                    let is_active: Bool
                    let requires_review: Bool?
                    let moderation_reason: String?
                    let open_house_date: Date?
                    let open_house_end_date: Date?
                    let open_house_paid: Bool?
                    let stripe_payment_id: String?

                    // Comprehensive property data
                    let school_district: String?
                    let elementary_school: String?
                    let middle_school: String?
                    let high_school: String?
                    let school_rating: Double?
                    let hoa_fee: Double?
                    let lot_size_sqft: Int?
                    let living_area_sqft: Int?
                    let year_built: Int?
                    let property_type_detail: String?
                    let parking_spaces: Int?
                    let stories: Int?
                    let heating_type: String?
                    let cooling_type: String?
                    let appliances_included: [String]?
                    let additional_details: [String: AnyCodable]?
                }

                // Determine living area square footage (prefer manual entry, fallback to API data)
                let livingAreaValue: Int? = {
                    if !squareFootage.isEmpty, let manualSqft = Int(squareFootage) {
                        print("   ℹ️ Using manual square footage: \(manualSqft)")
                        return manualSqft
                    } else if let apiSqft = comprehensiveData?.livingAreaSqft {
                        print("   ℹ️ Using API square footage: \(apiSqft)")
                        return apiSqft
                    } else {
                        print("   ℹ️ No square footage available")
                        return nil
                    }
                }()

                let newHome = NewHome(
                    user_id: userId.uuidString,
                    title: generatedTitle,
                    post_type: postType == .project ? "project" : "listing",
                    listing_type: postType == .listing ? (listingType == .sale ? "sale" : "rental") : nil,
                    description: description.isEmpty ? nil : description,
                    price: price.isEmpty ? nil : price,
                    bedrooms: bedrooms.isEmpty ? nil : Int(bedrooms),
                    bathrooms: bathrooms.isEmpty ? nil : bathrooms,
                    address: address.isEmpty ? nil : address,
                    unit: unit.isEmpty ? nil : unit,
                    city: city.isEmpty ? nil : city,
                    state: state.isEmpty ? nil : state,
                    zip_code: zipCode.isEmpty ? nil : zipCode,
                    image_urls: finalImageUrls,
                    before_photos: nil,  // Deprecated
                    photo_pairs: nil,  // Deprecated (before/after photos feature removed)
                    tags: generatedTags,
                    is_active: true,
                    requires_review: requiresReview ? true : nil,
                    moderation_reason: moderationReason,
                    open_house_date: (enableOpenHouse && hasOpenHousePaid) ? openHouseDate : nil,
                    open_house_end_date: (enableOpenHouse && hasOpenHousePaid) ? openHouseEndDate : nil,
                    open_house_paid: (enableOpenHouse && hasOpenHousePaid) ? true : nil,
                    stripe_payment_id: (enableOpenHouse && hasOpenHousePaid) ? stripePaymentId : nil,

                    // Comprehensive property data from API import
                    school_district: comprehensiveData?.schoolDistrict,
                    elementary_school: comprehensiveData?.elementarySchool,
                    middle_school: comprehensiveData?.middleSchool,
                    high_school: comprehensiveData?.highSchool,
                    school_rating: comprehensiveData?.schoolRating,
                    hoa_fee: comprehensiveData?.hoaFee,
                    lot_size_sqft: comprehensiveData?.lotSizeSqft,
                    living_area_sqft: livingAreaValue,
                    year_built: comprehensiveData?.yearBuilt,
                    property_type_detail: comprehensiveData?.propertyTypeDetail,
                    parking_spaces: comprehensiveData?.parkingSpaces,
                    stories: comprehensiveData?.stories,
                    heating_type: comprehensiveData?.heatingType,
                    cooling_type: comprehensiveData?.coolingType,
                    appliances_included: comprehensiveData?.appliancesIncluded,
                    additional_details: comprehensiveData?.additionalDetails
                )

                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .insert(newHome)
                    .select()
                    .execute()
                    .value

                print("✅ Post created successfully! Response: \(response)")

                // Notify FeedView to reload so the new post appears at the top
                print("📢 Sending NewPostCreated notification...")
                if let createdPost = response.first {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewPostCreated"),
                        object: nil,
                        userInfo: ["postId": createdPost.id]
                    )
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("NewPostCreated"), object: nil)
                }

                // Auto-post description as first comment if description exists
                if let createdHome = response.first, !description.isEmpty {
                    print("💬 Auto-posting description as first comment...")
                    struct NewComment: Encodable {
                        let home_id: String
                        let user_id: String
                        let comment_text: String
                    }

                    let comment = NewComment(
                        home_id: createdHome.id.uuidString,
                        user_id: userId.uuidString,
                        comment_text: description
                    )

                    do {
                        try await SupabaseManager.shared.client
                            .from("comments")
                            .insert(comment)
                            .execute()

                        print("✅ Description posted as first comment!")
                    } catch {
                        // Don't fail the whole post creation if comment fails
                        print("⚠️ Warning: Failed to post description as comment: \(error)")
                    }
                }

                isUploading = false
                print("🎉 Post creation complete, dismissing sheet...")
                dismiss()

            } catch {
                isUploading = false
                print("❌ Error creating post: \(error)")
                print("❌ Error details: \(String(describing: error))")
                errorMessage = error.localizedDescription
            }
        }
    }

    func updatePost() {
        guard let homeToEdit = editingHome else { return }

        print("🚀 updatePost() called")
        print("   - Images: \(imageData.count) local, \(imageUrls.count) URLs")
        print("   - Description: \(description.isEmpty ? "EMPTY" : "✓")")
        print("   - Price: \(price.isEmpty ? "EMPTY" : price)")
        print("   - Bedrooms: \(bedrooms.isEmpty ? "EMPTY" : bedrooms)")
        print("   - Bathrooms: \(bathrooms.isEmpty ? "EMPTY" : bathrooms)")
        print("   - Square Footage: \(squareFootage.isEmpty ? "EMPTY" : squareFootage)")
        print("   - Address: \(address.isEmpty ? "EMPTY" : address)")

        errorMessage = ""
        isUploading = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("📝 Updating post for user: \(userId)")

                // Upload new images to Supabase Storage (if any manually selected)
                var finalImageUrls: [String] = imageUrls // Start with existing/scraped URLs
                for (index, data) in imageData.enumerated() {
                    // Update progress on main thread
                    await MainActor.run {
                        uploadProgress = "Uploading image \(index + 1)/\(imageData.count)..."
                    }

                    // Compress image before upload
                    let compressedData: Data
                    if let image = UIImage(data: data) {
                        compressedData = compressImage(image) ?? data
                    } else {
                        compressedData = data
                    }

                    let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
                    print("📷 Uploading new image \(index + 1)/\(imageData.count)")

                    try await SupabaseManager.shared.client.storage
                        .from("home-images")
                        .upload(fileName, data: compressedData, options: .init(contentType: "image/jpeg"))

                    let publicURL = try SupabaseManager.shared.client.storage
                        .from("home-images")
                        .getPublicURL(path: fileName)

                    finalImageUrls.append(publicURL.absoluteString)
                    print("✅ Image uploaded: \(publicURL.absoluteString)")
                }

                // Clear progress message
                await MainActor.run {
                    uploadProgress = ""
                }

                // Generate title from address or price
                let generatedTitle: String
                if !address.isEmpty {
                    generatedTitle = address
                } else if !price.isEmpty {
                    generatedTitle = "$\(price) \(listingType.rawValue)"
                } else if !city.isEmpty && !state.isEmpty {
                    generatedTitle = "\(city), \(state)"
                } else {
                    generatedTitle = listingType.rawValue
                }

                // Determine living area square footage (prefer manual entry, fallback to API data, fallback to existing)
                let livingAreaValue: Int? = {
                    if !squareFootage.isEmpty, let manualSqft = Int(squareFootage) {
                        print("   ℹ️ Using manual square footage: \(manualSqft)")
                        return manualSqft
                    } else if let apiSqft = comprehensiveData?.livingAreaSqft {
                        print("   ℹ️ Using API square footage: \(apiSqft)")
                        return apiSqft
                    } else if let existingSqft = homeToEdit.livingAreaSqft {
                        print("   ℹ️ Keeping existing square footage: \(existingSqft)")
                        return existingSqft
                    } else {
                        print("   ℹ️ No square footage available")
                        return nil
                    }
                }()

                // Update home post
                struct UpdateHome: Encodable {
                    let title: String
                    let post_type: String
                    let listing_type: String?
                    let description: String?
                    let price: String?
                    let bedrooms: Int?
                    let bathrooms: String?
                    let living_area_sqft: Int?
                    let address: String?
                    let unit: String?
                    let city: String?
                    let state: String?
                    let zip_code: String?
                    let image_urls: [String]
                    let before_photos: [String]?
                    let photo_pairs: [[Int]]?
                }

                let updateData = UpdateHome(
                    title: generatedTitle,
                    post_type: postType == .project ? "project" : "listing",
                    listing_type: postType == .listing ? (listingType == .sale ? "sale" : "rental") : nil,
                    description: description.isEmpty ? nil : description,
                    price: price.isEmpty ? nil : price,
                    bedrooms: bedrooms.isEmpty ? nil : Int(bedrooms),
                    bathrooms: bathrooms.isEmpty ? nil : bathrooms,
                    living_area_sqft: livingAreaValue,
                    address: address.isEmpty ? nil : address,
                    unit: unit.isEmpty ? nil : unit,
                    city: city.isEmpty ? nil : city,
                    state: state.isEmpty ? nil : state,
                    zip_code: zipCode.isEmpty ? nil : zipCode,
                    image_urls: finalImageUrls,
                    before_photos: nil,  // Deprecated
                    photo_pairs: nil  // Deprecated (before/after photos feature removed)
                )

                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(updateData)
                    .eq("id", value: homeToEdit.id.uuidString)
                    .execute()

                print("✅ Post updated successfully!")
                isUploading = false

                // Notify feed to refresh
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)

                dismiss()

            } catch {
                isUploading = false
                print("❌ Error updating post: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func processOpenHousePayment() {
        // Clear any previous errors
        errorMessage = ""
        isProcessingPayment = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                print("💳 Processing Open House payment...")

                // Call StripeManager to handle payment
                StripeManager.shared.processOpenHousePayment(userId: userId.uuidString, homeId: "new") { result in
                    DispatchQueue.main.async {
                        self.isProcessingPayment = false

                        switch result {
                        case .success(let paymentIntentId):
                            print("✅ Payment successful!")
                            self.hasOpenHousePaid = true
                            self.stripePaymentId = paymentIntentId
                        case .failure(let error):
                            print("❌ Payment failed: \(error.localizedDescription)")
                            self.errorMessage = "Payment Error: \(error.localizedDescription)"
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessingPayment = false
                    self.errorMessage = "Authentication Error: \(error.localizedDescription)"
                }
            }
        }
    }

    // Cancel open house
    func cancelOpenHouse() {
        guard let home = editingHome else {
            print("❌ No home to cancel open house for")
            return
        }

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Check if user owns this post
                if home.userId != userId {
                    print("❌ User does not own this post")
                    return
                }

                print("🚫 Cancelling open house for home: \(home.id)")

                // Get all users who saved this open house
                struct SavedBy: Codable {
                    let userId: UUID

                    enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                    }
                }

                let savedByUsers: [SavedBy] = try await SupabaseManager.shared.client
                    .from("saved_open_houses")
                    .select("user_id")
                    .eq("home_id", value: home.id.uuidString)
                    .execute()
                    .value

                print("📢 Notifying \(savedByUsers.count) users who saved this open house")

                // Create notifications for each user who saved it
                for savedUser in savedByUsers {
                    struct NewNotification: Encodable {
                        let user_id: String
                        let triggered_by_user_id: String
                        let type: String
                        let title: String
                        let message: String
                        let home_id: String
                    }

                    let address = home.address ?? "a property"
                    let notification = NewNotification(
                        user_id: savedUser.userId.uuidString,
                        triggered_by_user_id: userId.uuidString,
                        type: "open_house_cancelled",
                        title: "Open House Cancelled",
                        message: "The open house at \(address) has been cancelled by the owner.",
                        home_id: home.id.uuidString
                    )

                    try await SupabaseManager.shared.client
                        .from("notifications")
                        .insert(notification)
                        .execute()
                }

                // Update the home to remove open house info
                struct OpenHouseUpdate: Encodable {
                    let open_house_paid: Bool?
                    let open_house_date: Date?
                    let open_house_end_date: Date?
                    let stripe_payment_id: String?
                }

                let update = OpenHouseUpdate(
                    open_house_paid: nil,
                    open_house_date: nil,
                    open_house_end_date: nil,
                    stripe_payment_id: nil
                )

                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                print("✅ Open house cancelled successfully")

                // Update local state
                await MainActor.run {
                    hasOpenHousePaid = false
                    enableOpenHouse = false
                    stripePaymentId = nil
                }

                // Notify other views to refresh
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshOpenHouseList"), object: nil)

                // Dismiss this view
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error cancelling open house: \(error)")
                await MainActor.run {
                    errorMessage = "Error cancelling open house: \(error.localizedDescription)"
                }
            }
        }
    }

    // Image compression helper function
    func compressImage(_ image: UIImage) -> Data? {
        // Start with high quality (0.9) to preserve image quality
        if let data = image.jpegData(compressionQuality: 0.9) {
            // Only compress further if image is very large (> 5MB)
            if data.count > 5_000_000 {
                // Use 0.85 quality - still very high quality but smaller size
                return image.jpegData(compressionQuality: 0.85)
            }
            return data
        }
        return nil
    }
}

#Preview {
    CreatePostView()
}

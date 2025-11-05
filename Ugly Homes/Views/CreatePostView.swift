//
//  CreatePostView.swift
//  Ugly Homes
//
//  Create Post View
//

import SwiftUI
import PhotosUI
import UIKit

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss

    let editingHome: Home?

    @State private var listingURL = ""
    @State private var listingType: ListingType = .sale
    @State private var description = ""
    @State private var price = ""
    @State private var bedrooms = ""
    @State private var bathrooms = ""
    @State private var address = ""
    @State private var unit = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var hideLocation = false
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

    enum ListingType: String, CaseIterable {
        case sale = "For Sale"
        case rental = "For Rent"
    }

    init(editingHome: Home? = nil) {
        self.editingHome = editingHome

        // Pre-populate fields if editing
        if let home = editingHome {
            _listingType = State(initialValue: home.listingType == "rental" ? .rental : .sale)
            _description = State(initialValue: home.description ?? "")
            _price = State(initialValue: home.price?.description ?? "")
            _bedrooms = State(initialValue: home.bedrooms != nil ? String(home.bedrooms!) : "")
            _bathrooms = State(initialValue: home.bathrooms != nil ? String(NSDecimalNumber(decimal: home.bathrooms!).doubleValue) : "")
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
        let hasPrice = !price.isEmpty
        let hasBedrooms = !bedrooms.isEmpty
        let hasBathrooms = !bathrooms.isEmpty

        // If location is not hidden, address is required
        let locationValid = hideLocation || !address.isEmpty

        return hasPhotos && hasDescription && hasPrice && hasBedrooms && hasBathrooms && locationValid
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // URL Import Section (only show when creating new property)
                    if editingHome == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Import")
                                .font(.system(size: 15, weight: .medium))
                            Text("Paste a Zillow URL")
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
                            if !errorMessage.isEmpty && errorMessage.contains("Cannot connect") {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.top, 4)
                            } else if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(errorMessage.contains("✅") ? .green : .red)
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

                    // Listing Type Picker
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

                    // Image picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos")
                            .font(.system(size: 15, weight: .medium))
                        Text("Select up to 15 photos (at least 1 required)")
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
                                        // Show imported URL images with controls
                                        ForEach(0..<imageUrls.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                AsyncImage(url: URL(string: imageUrls[index])) { image in
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

                                                // Delete button
                                                Button(action: {
                                                    imageUrls.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                        .font(.title3)
                                                }
                                                .padding(8)

                                                // Photo number badge and reorder controls
                                                VStack {
                                                    Spacer()
                                                    HStack(spacing: 4) {
                                                        // Move left button
                                                        if index > 0 {
                                                            Button(action: {
                                                                imageUrls.swapAt(index, index - 1)
                                                            }) {
                                                                Image(systemName: "chevron.left.circle.fill")
                                                                    .foregroundColor(.white)
                                                                    .background(Circle().fill(Color.orange.opacity(0.8)))
                                                                    .font(.title3)
                                                            }
                                                        }

                                                        Text("\(index + 1)")
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                            .padding(6)
                                                            .background(Circle().fill(Color.black.opacity(0.6)))

                                                        // Move right button
                                                        if index < imageUrls.count - 1 {
                                                            Button(action: {
                                                                imageUrls.swapAt(index, index + 1)
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

                                        // Show locally selected images with controls
                                        ForEach(0..<imageData.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                if let uiImage = UIImage(data: imageData[index]) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 150, height: 150)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                }

                                                // Delete button
                                                Button(action: {
                                                    imageData.remove(at: index)
                                                    selectedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                        .font(.title3)
                                                }
                                                .padding(8)

                                                // Photo number badge and reorder controls
                                                VStack {
                                                    Spacer()
                                                    HStack(spacing: 4) {
                                                        // Move left button
                                                        if index > 0 || imageUrls.count > 0 {
                                                            Button(action: {
                                                                if index > 0 {
                                                                    imageData.swapAt(index, index - 1)
                                                                    selectedImages.swapAt(index, index - 1)
                                                                } else if imageUrls.count > 0 {
                                                                    // Move from imageData to end of imageUrls
                                                                    _ = imageData.remove(at: index)
                                                                    selectedImages.remove(at: index)
                                                                    imageUrls.append("")  // placeholder for now
                                                                }
                                                            }) {
                                                                Image(systemName: "chevron.left.circle.fill")
                                                                    .foregroundColor(.white)
                                                                    .background(Circle().fill(Color.orange.opacity(0.8)))
                                                                    .font(.title3)
                                                            }
                                                        }

                                                        Text("\(imageUrls.count + index + 1)")
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                            .padding(6)
                                                            .background(Circle().fill(Color.black.opacity(0.6)))

                                                        // Move right button
                                                        if index < imageData.count - 1 {
                                                            Button(action: {
                                                                imageData.swapAt(index, index + 1)
                                                                selectedImages.swapAt(index, index + 1)
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
                                        if (imageUrls.count + imageData.count) < 15 {
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
                        Text("Description")
                            .font(.system(size: 15, weight: .medium))
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Price
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

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.system(size: 15, weight: .medium))

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
            .navigationTitle(editingHome == nil ? "New Property" : "Edit Property")
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

    func importFromURL() {
        guard !listingURL.isEmpty else { return }
        errorMessage = ""
        isImporting = true

        Task {
            do {
                print("🔄 Starting import from URL: \(listingURL)")

                // Call the optional scraping API for auto-import
                // NOTE: This is optional - if unavailable, users can fill form manually
                // To update IP: Open Config.swift and change developmentIP
                let apiEndpoint = APIConfig.scrapingAPIEndpoint

                guard let apiURL = URL(string: apiEndpoint) else {
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Quick import is taking a break - just add your listing below!"])
                }

                var request = URLRequest(url: apiURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30 // 30 second timeout - allows time for photo fetching

                let body = ["url": listingURL]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                print("📡 Sending request to scraping API...")
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Quick import is busy - add your listing below!"])
                }

                print("📥 Received response with status code: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    // Try to parse error message from response
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = errorResponse["error"] as? String {
                        throw NSError(domain: "ImportError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "🤔 \(errorMsg) - just add your details below!"])
                    } else {
                        throw NSError(domain: "ImportError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "📈 Quick import is experiencing high demand - add your listing below!"])
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
                }

                let scraped = try JSONDecoder().decode(ScrapedListing.self, from: data)
                print("✅ Successfully parsed listing data")

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
                    self.description = desc
                    fieldsPopulated += 1
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

                isImporting = false

                if fieldsPopulated > 0 {
                    errorMessage = "✅ Successfully imported \(fieldsPopulated) field(s)!"
                    print("✅ Successfully imported listing data - \(fieldsPopulated) fields populated")

                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.errorMessage.contains("Successfully") {
                            self.errorMessage = ""
                        }
                    }
                } else {
                    errorMessage = "🤔 Couldn't read that listing - no worries, just add your details below!"
                    print("⚠️ No data was extracted from the listing")
                }

            } catch let error as NSError {
                print("⚠️ Import failed (non-critical): \(error.localizedDescription)")

                // Friendly error message - import is optional
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotConnectToHost {
                    errorMessage = "📈 We're growing fast! Quick import is taking a break - just fill out the form below"
                } else if error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
                    errorMessage = "📈 High demand right now! Fill out the form below while our servers catch up"
                } else {
                    errorMessage = "✨ Quick import is busy - no worries, just add your listing details below!"
                }

                print("ℹ️ User can continue posting manually")

                // Auto-dismiss error after 5 seconds so it doesn't block the user
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if self.errorMessage.contains("Import") {
                        self.errorMessage = ""
                    }
                }

                isImporting = false
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
        print("   - Address: \(address.isEmpty ? "EMPTY" : address)")

        errorMessage = ""
        isUploading = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("📤 Creating post for user: \(userId)")

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

                // Generate hashtags
                let priceDecimal: Decimal? = {
                    guard !price.isEmpty, let priceDouble = Double(price) else { return nil }
                    return Decimal(priceDouble)
                }()

                var generatedTags = TagGenerator.generateTags(
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

                print("🏷️ Generated tags: \(generatedTags)")

                // Create home post
                struct NewHome: Encodable {
                    let user_id: String
                    let title: String
                    let listing_type: String
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
                    let tags: [String]
                    let is_active: Bool
                    let open_house_date: Date?
                    let open_house_end_date: Date?
                    let open_house_paid: Bool?
                    let stripe_payment_id: String?
                }

                let newHome = NewHome(
                    user_id: userId.uuidString,
                    title: generatedTitle,
                    listing_type: listingType == .sale ? "sale" : "rental",
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
                    tags: generatedTags,
                    is_active: true,
                    open_house_date: (enableOpenHouse && hasOpenHousePaid) ? openHouseDate : nil,
                    open_house_end_date: (enableOpenHouse && hasOpenHousePaid) ? openHouseEndDate : nil,
                    open_house_paid: (enableOpenHouse && hasOpenHousePaid) ? true : nil,
                    stripe_payment_id: (enableOpenHouse && hasOpenHousePaid) ? stripePaymentId : nil
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

                // Update home post
                struct UpdateHome: Encodable {
                    let title: String
                    let listing_type: String
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
                }

                let updateData = UpdateHome(
                    title: generatedTitle,
                    listing_type: listingType == .sale ? "sale" : "rental",
                    description: description.isEmpty ? nil : description,
                    price: price.isEmpty ? nil : price,
                    bedrooms: bedrooms.isEmpty ? nil : Int(bedrooms),
                    bathrooms: bathrooms.isEmpty ? nil : bathrooms,
                    address: address.isEmpty ? nil : address,
                    unit: unit.isEmpty ? nil : unit,
                    city: city.isEmpty ? nil : city,
                    state: state.isEmpty ? nil : state,
                    zip_code: zipCode.isEmpty ? nil : zipCode,
                    image_urls: finalImageUrls
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

//
//  CreatePostView.swift
//  Ugly Homes
//
//  Create Post View
//

import SwiftUI
import PhotosUI

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

    // Open House feature
    @State private var enableOpenHouse = false
    @State private var openHouseDate = Date().addingTimeInterval(86400) // Default tomorrow
    @State private var openHouseEndDate = Date().addingTimeInterval(86400 + 7200) // Default +2 hours
    @State private var hasOpenHousePaid = false
    @State private var stripePaymentId: String?
    @State private var showPaymentSheet = false
    @State private var isProcessingPayment = false

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
            _city = State(initialValue: home.city ?? "")
            _state = State(initialValue: home.state ?? "")
            _zipCode = State(initialValue: home.zipCode ?? "")
            _imageUrls = State(initialValue: home.imageUrls)
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
                            Text("Paste a Zillow or Redfin URL")
                                .font(.caption)
                                .foregroundColor(.gray)

                        HStack {
                            TextField("Paste listing URL here", text: $listingURL)
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
                    }

                    if editingHome == nil {
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

                    // Open House Section (only when creating new property)
                    if editingHome == nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()
                                .padding(.vertical, 8)

                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundColor(.orange)
                                Text("Open House Feature")
                                    .font(.headline)
                                Spacer()
                                Text("$5")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }

                            Text("Add a gold 'OPEN HOUSE' badge to your listing with the date and time")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Toggle("Enable Open House", isOn: $enableOpenHouse)
                                .tint(.orange)

                            if enableOpenHouse {
                                VStack(alignment: .leading, spacing: 12) {
                                    DatePicker("Start Date & Time", selection: $openHouseDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)

                                    DatePicker("End Date & Time", selection: $openHouseEndDate, in: openHouseDate..., displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)

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
                                                    Text("Pay $5 via Apple Pay")
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
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }

                    // Post button
                    Button(action: editingHome == nil ? createPost : updatePost) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
        }
    }

    func importFromURL() {
        guard !listingURL.isEmpty else { return }
        errorMessage = ""
        isImporting = true

        Task {
            do {
                print("🔄 Starting import from URL: \(listingURL)")

                // Call the scraping API (real endpoint - may be blocked by anti-bot protection)
                // Use localhost for simulator, or your Mac's IP for physical device
                guard let apiURL = URL(string: "http://10.2.224.251:3000/api/scrape-listing") else {
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
                }

                var request = URLRequest(url: apiURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30 // 30 second timeout

                let body = ["url": listingURL]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                print("📡 Sending request to scraping API...")
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                }

                print("📥 Received response with status code: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    // Try to parse error message from response
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = errorResponse["error"] as? String {
                        throw NSError(domain: "ImportError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                    } else {
                        throw NSError(domain: "ImportError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error code \(httpResponse.statusCode)"])
                    }
                }

                struct ScrapedListing: Codable {
                    let price: String?
                    let address: String?
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
                    errorMessage = "⚠️ No data could be extracted from this URL"
                    print("⚠️ No data was extracted from the listing")
                }

            } catch let error as NSError {
                print("❌ Error importing listing: \(error)")
                print("❌ Error details: \(error.localizedDescription)")

                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotConnectToHost {
                    errorMessage = "Cannot connect to server. Make sure API is running at localhost:3000"
                } else if error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
                    errorMessage = "Request timed out. Server may be slow or unresponsive."
                } else {
                    errorMessage = error.localizedDescription
                }

                isImporting = false
            }
        }
    }

    func createPost() {
        errorMessage = ""
        isUploading = true

        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                print("📤 Creating post for user: \(userId)")

                // Upload images to Supabase Storage (if manually selected)
                var finalImageUrls: [String] = imageUrls // Start with scraped URLs if any
                for (index, data) in imageData.enumerated() {
                    let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"

                    print("📷 Uploading image \(index + 1)/\(imageData.count)")

                    try await SupabaseManager.shared.client.storage
                        .from("home-images")
                        .upload(fileName, data: data, options: .init(contentType: "image/jpeg"))

                    let publicURL = try SupabaseManager.shared.client.storage
                        .from("home-images")
                        .getPublicURL(path: fileName)

                    finalImageUrls.append(publicURL.absoluteString)
                    print("✅ Image uploaded: \(publicURL.absoluteString)")
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
                    let city: String?
                    let state: String?
                    let zip_code: String?
                    let image_urls: [String]
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
                    city: city.isEmpty ? nil : city,
                    state: state.isEmpty ? nil : state,
                    zip_code: zipCode.isEmpty ? nil : zipCode,
                    image_urls: finalImageUrls,
                    is_active: true,
                    open_house_date: (enableOpenHouse && hasOpenHousePaid) ? openHouseDate : nil,
                    open_house_end_date: (enableOpenHouse && hasOpenHousePaid) ? openHouseEndDate : nil,
                    open_house_paid: (enableOpenHouse && hasOpenHousePaid) ? true : nil,
                    stripe_payment_id: (enableOpenHouse && hasOpenHousePaid) ? stripePaymentId : nil
                )

                try await SupabaseManager.shared.client
                    .from("homes")
                    .insert(newHome)
                    .execute()

                print("✅ Post created successfully!")
                isUploading = false
                dismiss()

            } catch {
                isUploading = false
                print("❌ Error creating post: \(error)")
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
                    let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
                    print("📷 Uploading new image \(index + 1)/\(imageData.count)")

                    try await SupabaseManager.shared.client.storage
                        .from("home-images")
                        .upload(fileName, data: data, options: .init(contentType: "image/jpeg"))

                    let publicURL = try SupabaseManager.shared.client.storage
                        .from("home-images")
                        .getPublicURL(path: fileName)

                    finalImageUrls.append(publicURL.absoluteString)
                    print("✅ Image uploaded: \(publicURL.absoluteString)")
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
                NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)

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
}

#Preview {
    CreatePostView()
}

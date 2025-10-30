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
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var imageData: [Data] = []
    @State private var imageUrls: [String] = []
    @State private var isUploading = false
    @State private var isImporting = false
    @State private var errorMessage = ""

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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // URL Import Section (only show when creating new post)
                    if editingHome == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Import")
                                .fontWeight(.semibold)
                            Text("Paste a Zillow (sales) or Redfin (rentals) URL")
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
                            .fontWeight(.semibold)
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
                            .fontWeight(.semibold)
                        Text("Select up to 10 photos")
                            .font(.caption)
                            .foregroundColor(.gray)

                        // Show imported images if available
                        if !imageUrls.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(0..<imageUrls.count, id: \.self) { index in
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
                                    }
                                }
                            }
                            .frame(height: 150)

                            Text("\(imageUrls.count) photo\(imageUrls.count == 1 ? "" : "s") imported")
                                .font(.caption)
                                .foregroundColor(.green)

                            Button(action: {
                                imageUrls = []
                            }) {
                                Text("Clear imported photos")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        // Photo preview and picker
                        VStack(alignment: .leading, spacing: 8) {
                            if imageUrls.isEmpty && imageData.isEmpty {
                                PhotosPicker(
                                    selection: $selectedImages,
                                    maxSelectionCount: 10,
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
                                        // Show imported URL images
                                        ForEach(0..<imageUrls.count, id: \.self) { index in
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
                                                    .overlay(
                                                        ProgressView()
                                                    )
                                            }
                                        }

                                        // Show locally selected images
                                        ForEach(0..<imageData.count, id: \.self) { index in
                                            if let uiImage = UIImage(data: imageData[index]) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 150, height: 150)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                        }

                                        // Add more button
                                        PhotosPicker(
                                            selection: $selectedImages,
                                            maxSelectionCount: 10,
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
                                .frame(height: 150)
                            }

                            let totalPhotos = imageUrls.count + imageData.count
                            if totalPhotos > 0 {
                                Text("\(totalPhotos) photo\(totalPhotos == 1 ? "" : "s") selected")
                                    .font(.caption)
                                    .foregroundColor(.gray)
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
                        Text("Description (Optional)")
                            .fontWeight(.semibold)
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Price
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price (Optional)")
                            .fontWeight(.semibold)
                        TextField("$0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Bedrooms and Bathrooms
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bedrooms (Optional)")
                                .fontWeight(.semibold)
                            TextField("0", text: $bedrooms)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bathrooms (Optional)")
                                .fontWeight(.semibold)
                            TextField("0", text: $bathrooms)
                                .keyboardType(.decimalPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location (Optional)")
                            .fontWeight(.semibold)

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

                    // Post button
                    Button(action: editingHome == nil ? createPost : updatePost) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(editingHome == nil ? "Post Ugly Home" : "Update Post")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background((imageData.isEmpty && imageUrls.isEmpty) ? Color.gray : Color.orange)
                    .cornerRadius(10)
                    .disabled((imageData.isEmpty && imageUrls.isEmpty) || isUploading)
                }
                .padding()
            }
            .navigationTitle(editingHome == nil ? "New Post" : "Edit Post")
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
                    is_active: true
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
}

#Preview {
    CreatePostView()
}

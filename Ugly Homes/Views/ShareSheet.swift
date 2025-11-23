//
//  ShareSheet.swift
//  Ugly Homes
//
//  Custom share sheet with Instagram integration
//

import SwiftUI
import UIKit

struct ShareSheet: View {
    let home: Home
    @Environment(\.dismiss) var dismiss
    @State private var showCopiedMessage = false

    var shareURL: String {
        // Use Universal Link (opens app if installed, web page if not)
        return "https://www.housers.us/property/\(home.id.uuidString)"
    }

    var shareText: String {
        """
        Check out this home on Houser

        \(home.title)
        \(home.price != nil ? formatPrice(home.price!) : "")
        \(home.address ?? ""), \(home.city ?? "")
        """
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Share")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
                .overlay(
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 16),
                    alignment: .trailing
                )

                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        // Property preview
                        VStack(spacing: 12) {
                            if let imageUrl = home.imageUrls.first {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 180)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(12)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 180)
                                        .cornerRadius(12)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(home.title)
                                    .font(.headline)
                                    .lineLimit(2)

                                if let price = home.price {
                                    Text(formatPrice(price))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }

                                if let address = home.address, let city = home.city {
                                    Text("\(address), \(city)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // Share options
                        VStack(spacing: 0) {
                            // Instagram Stories - Featured
                            Button(action: shareToInstagramStories) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.83, green: 0.22, blue: 0.61),
                                                Color(red: 0.99, green: 0.42, blue: 0.31),
                                                Color(red: 1.0, green: 0.84, blue: 0.18)
                                            ]),
                                            startPoint: .bottomLeading,
                                            endPoint: .topTrailing
                                        )
                                        .frame(width: 44, height: 44)
                                        .cornerRadius(12)

                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Instagram Stories")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)

                                        Text("Share to your story")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            // Other share options grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 20) {
                                // Copy Link
                                ShareOptionButton(
                                    icon: "link",
                                    title: "Copy Link",
                                    color: .blue
                                ) {
                                    copyLink()
                                }

                                // Messages (SMS)
                                ShareOptionButton(
                                    icon: "message.fill",
                                    title: "Messages",
                                    color: .green
                                ) {
                                    shareViaMessages()
                                }

                                // WhatsApp
                                ShareOptionButton(
                                    icon: "bubble.left.fill",
                                    title: "WhatsApp",
                                    color: Color(red: 0.15, green: 0.78, blue: 0.42)
                                ) {
                                    shareViaWhatsApp()
                                }

                                // Email (Gmail)
                                ShareOptionButton(
                                    icon: "envelope.fill",
                                    title: "Email",
                                    color: .red
                                ) {
                                    shareViaEmail()
                                }

                                // More
                                ShareOptionButton(
                                    icon: "ellipsis.circle.fill",
                                    title: "More",
                                    color: .orange
                                ) {
                                    showSystemShareSheet()
                                }
                            }
                            .padding()
                        }

                        // Copied message
                        if showCopiedMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Link copied!")
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    func shareToInstagramStories() {
        trackShare()

        guard let image = home.imageUrls.first,
              let imageURL = URL(string: image),
              let imageData = try? Data(contentsOf: imageURL),
              let instagramURL = URL(string: "instagram-stories://share?source_application=com.housers.app") else {
            // Fallback to Instagram app or App Store
            if let instagramAppURL = URL(string: "instagram://app") {
                UIApplication.shared.open(instagramAppURL)
            } else if let appStoreURL = URL(string: "https://apps.apple.com/app/instagram/id389801252") {
                UIApplication.shared.open(appStoreURL)
            }
            return
        }

        // Check if Instagram is installed
        if UIApplication.shared.canOpenURL(instagramURL) {
            // Create pasteboard items for Instagram Stories (clean image, no overlays)
            let pasteboardDict: [String: Any] = [
                "com.instagram.sharedSticker.backgroundImage": imageData,
                "com.instagram.sharedSticker.contentURL": shareURL
            ]

            let pasteboardItems: [[String: Any]] = [pasteboardDict]

            let pasteboardOptions = [
                UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(60 * 5)
            ]

            UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
            UIApplication.shared.open(instagramURL)

            dismiss()
        } else {
            // Instagram not installed, open App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/app/instagram/id389801252") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }

    // REMOVED: Instagram Feed (not seamless, requires manual posting)
    // Keeping function commented out in case needed later
    /*
    func shareToInstagramFeed() {
        trackShare()

        guard let imageUrl = home.imageUrls.first,
              let url = URL(string: imageUrl) else {
            print("❌ No image URL available")
            return
        }

        // Download and save image to Photos
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    print("❌ Failed to create image from data")
                    return
                }

                // Save to Photos
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

                // Show success alert with instructions
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "✅ Saved to Photos!",
                        message: "Image saved successfully. Open Instagram and create a new post from your Photos to share this property.",
                        preferredStyle: .alert
                    )

                    alert.addAction(UIAlertAction(title: "Open Instagram", style: .default) { _ in
                        // Try to open Instagram app
                        if let instagramURL = URL(string: "instagram://app"),
                           UIApplication.shared.canOpenURL(instagramURL) {
                            UIApplication.shared.open(instagramURL)
                        } else if let appStoreURL = URL(string: "https://apps.apple.com/app/instagram/id389801252") {
                            UIApplication.shared.open(appStoreURL)
                        }
                        dismiss()
                    })

                    alert.addAction(UIAlertAction(title: "OK", style: .cancel) { _ in
                        dismiss()
                    })

                    // Present alert
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        var topController = rootVC
                        while let presented = topController.presentedViewController {
                            topController = presented
                        }
                        topController.present(alert, animated: true)
                    }
                }

            } catch {
                print("❌ Failed to download image: \(error)")
            }
        }
    }
    */

    func copyLink() {
        trackShare()
        UIPasteboard.general.string = shareURL

        withAnimation {
            showCopiedMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedMessage = false
            }
        }
    }

    func shareViaMessages() {
        trackShare()

        // Create beautiful composite image with property info
        Task {
            var itemsToShare: [Any] = []

            // Generate composite share image with text overlay
            print("🎨 Starting to create composite share image...")
            if let shareImage = await createShareImage() {
                print("✅ Composite image created! Size: \(shareImage.size)")

                // Use UIImage directly instead of file URL to avoid file provider issues
                itemsToShare.append(shareImage)
            } else {
                print("⚠️ Composite generation failed, using original image")
                // Fallback to original image
                if let imageUrl = home.imageUrls.first, let url = URL(string: imageUrl) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            itemsToShare.append(image)
                            print("✅ Using original image as fallback")
                        }
                    } catch {
                        print("❌ Fallback failed: \(error.localizedDescription)")
                    }
                }
            }

            // Add text with URL
            let shareMessage = """
            Check out this home on Houser

            \(home.title)
            \(home.price != nil ? formatPrice(home.price!) : "")

            \(shareURL)
            """
            itemsToShare.append(shareMessage)

            print("📤 Sharing \(itemsToShare.count) items")
            for (index, item) in itemsToShare.enumerated() {
                print("   Item \(index): \(type(of: item))")
            }

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: itemsToShare,
                    applicationActivities: nil
                )

                // Add completion handler to dismiss after sharing is done
                activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                    print("📊 Share activity completed: \(completed)")
                    if let error = error {
                        print("❌ Share error: \(error.localizedDescription)")
                    }
                    if let activityType = activityType {
                        print("✅ Shared via: \(activityType.rawValue)")
                    }

                    // Dismiss the parent share sheet
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    topController.present(activityVC, animated: true)
                }
            }
        }
    }

    // Create beautiful share image with property info overlaid
    func createShareImage() async -> UIImage? {
        print("🖼️ Image URL: \(home.imageUrls.first ?? "none")")

        guard let imageUrl = home.imageUrls.first else {
            print("❌ No image URL")
            return nil
        }

        guard let url = URL(string: imageUrl) else {
            print("❌ Invalid URL")
            return nil
        }

        print("⬇️ Downloading image from: \(url)")

        // Use async URLSession for reliable image download
        let imageData: Data
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Verify response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP status: \(httpResponse.statusCode)")
                guard httpResponse.statusCode == 200 else {
                    print("❌ HTTP error: \(httpResponse.statusCode)")
                    return nil
                }
            }

            imageData = data
            print("✅ Downloaded \(imageData.count) bytes")
        } catch {
            print("❌ Failed to download image data: \(error.localizedDescription)")
            return nil
        }

        guard let propertyImage = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from data")
            return nil
        }

        print("✅ Created UIImage: \(propertyImage.size)")

        let size = CGSize(width: 1080, height: 1080) // Square format for best compatibility
        let renderer = UIGraphicsImageRenderer(size: size)

        let compositeImage = renderer.image { context in
            // Draw property image (fill entire canvas)
            propertyImage.draw(in: CGRect(origin: .zero, size: size))

            // Draw gradient overlay at bottom for text readability
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(x: 0, y: size.height - 300, width: size.width, height: 300)
            gradientLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.7).cgColor
            ]
            gradientLayer.render(in: context.cgContext)

            // Draw text
            let textColor = UIColor.white
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            // Title
            let addressText = home.title
            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
            addressText.draw(in: CGRect(x: 40, y: size.height - 220, width: size.width - 80, height: 60),
                           withAttributes: addressAttributes)

            // Price
            if let price = home.price {
                let priceText = formatPrice(price)
                let priceAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 42),
                    .foregroundColor: UIColor.systemOrange,
                    .paragraphStyle: paragraphStyle
                ]
                priceText.draw(in: CGRect(x: 40, y: size.height - 150, width: size.width - 80, height: 50),
                             withAttributes: priceAttributes)
            }

            // Full address
            let fullAddress = "\(home.address ?? ""), \(home.city ?? "")"
            let fullAddressAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32),
                .foregroundColor: textColor.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
            fullAddress.draw(in: CGRect(x: 40, y: size.height - 90, width: size.width - 80, height: 40),
                           withAttributes: fullAddressAttributes)
        }

        print("✅ Composite image created successfully!")
        return compositeImage
    }

    func shareViaWhatsApp() {
        trackShare()

        let messageText = "\(shareText)\n\n\(shareURL)"
        let encodedText = messageText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let whatsappURL = "whatsapp://send?text=\(encodedText)"

        if let url = URL(string: whatsappURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            dismiss()
        } else {
            // WhatsApp not installed, open App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/app/whatsapp-messenger/id310633997") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }

    func shareViaFacebook() {
        trackShare()

        // Facebook sharing via URL scheme
        let fbURL = "fb://facewebmodal/f?href=\(shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: fbURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            dismiss()
        } else {
            // Facebook not installed, open web share
            if let webURL = URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(webURL)
                dismiss()
            }
        }
    }

    func shareViaEmail() {
        trackShare()

        let subject = "Check out this home on Houser"
        let bodyWithLink = """
        \(shareText)

        \(shareURL)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = bodyWithLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let mailURL = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailURL) {
            UIApplication.shared.open(url)
            dismiss()
        }
    }

    func showSystemShareSheet() {
        trackShare()

        // Create beautiful composite image with property info
        Task {
            var itemsToShare: [Any] = []

            // Generate composite share image with text overlay
            print("🎨 Starting to create composite share image...")
            if let shareImage = await createShareImage() {
                print("✅ Composite image created! Size: \(shareImage.size)")

                // Use UIImage directly instead of file URL to avoid file provider issues
                itemsToShare.append(shareImage)
            } else {
                print("⚠️ Composite generation failed, using original image")
                // Fallback to original image
                if let imageUrl = home.imageUrls.first, let url = URL(string: imageUrl) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            itemsToShare.append(image)
                            print("✅ Using original image as fallback")
                        }
                    } catch {
                        print("❌ Fallback failed: \(error.localizedDescription)")
                    }
                }
            }

            // Add text with URL
            let shareMessage = """
            Check out this home on Houser

            \(home.title)
            \(home.price != nil ? formatPrice(home.price!) : "")

            \(shareURL)
            """
            itemsToShare.append(shareMessage)

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: itemsToShare,
                    applicationActivities: nil
                )

                // Add completion handler to dismiss after sharing is done
                activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                    print("📊 Share activity completed: \(completed)")
                    if let error = error {
                        print("❌ Share error: \(error.localizedDescription)")
                    }
                    if let activityType = activityType {
                        print("✅ Shared via: \(activityType.rawValue)")
                    }

                    // Dismiss the parent share sheet
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    // Find the top-most view controller
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    topController.present(activityVC, animated: true)
                }
            }
        }
    }

    func trackShare() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                struct NewShare: Encodable {
                    let home_id: String
                    let user_id: String
                }

                try await SupabaseManager.shared.client
                    .from("shares")
                    .insert(NewShare(home_id: home.id.uuidString, user_id: userId.uuidString))
                    .execute()
                print("✅ Share tracked successfully")
            } catch {
                print("❌ Error tracking share: \(error)")
            }
        }
    }

    func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let nsDecimal = NSDecimalNumber(decimal: price)
        return "$" + (formatter.string(from: nsDecimal) ?? "\(price)")
    }
}

struct ShareOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    ShareSheet(home: Home(
        id: UUID(),
        userId: UUID(),
        title: "Beautiful fixer-upper",
        listingType: "sale",
        description: "Needs some TLC",
        price: 250000,
        address: "123 Main St",
        city: "San Francisco",
        state: "CA",
        zipCode: "94102",
        bedrooms: 3,
        bathrooms: 2,
        imageUrls: ["https://via.placeholder.com/400"],
        likesCount: 0,
        commentsCount: 0,
        isActive: true,
        createdAt: Date(),
        updatedAt: Date()
    ))
}

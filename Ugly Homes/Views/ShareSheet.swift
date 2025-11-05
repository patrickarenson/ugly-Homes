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
        // Use custom URL scheme for direct app opening
        return "housers://home/\(home.id.uuidString)"
    }

    var shareText: String {
        """
        Check out this home on Housers!

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

                                // Facebook
                                ShareOptionButton(
                                    icon: "f.circle.fill",
                                    title: "Facebook",
                                    color: Color(red: 0.23, green: 0.35, blue: 0.6)
                                ) {
                                    shareViaFacebook()
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
            // Load Housers logo as sticker overlay
            var stickerData: Data?
            if let logoImage = UIImage(named: "HousersLogo") {
                // Resize logo to be smaller (sticker size)
                let targetSize = CGSize(width: 120, height: 120)
                UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
                logoImage.draw(in: CGRect(origin: .zero, size: targetSize))
                let resizedLogo = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                stickerData = resizedLogo?.pngData()
            }

            // Create pasteboard items for Instagram Stories
            var pasteboardDict: [String: Any] = [
                "com.instagram.sharedSticker.backgroundImage": imageData,
                "com.instagram.sharedSticker.contentURL": shareURL
            ]

            // Add logo as sticker overlay if available
            if let stickerData = stickerData {
                pasteboardDict["com.instagram.sharedSticker.stickerImage"] = stickerData
            }

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

        // Load the image to share along with text
        Task {
            var itemsToShare: [Any] = [shareText, shareURL]

            // Download and add image if available
            if let imageUrl = home.imageUrls.first,
               let url = URL(string: imageUrl),
               let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                itemsToShare.insert(image, at: 0) // Add image first
            }

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: itemsToShare,
                    applicationActivities: nil
                )

                // Restrict to Messages only
                activityVC.excludedActivityTypes = [
                    .postToFacebook,
                    .postToTwitter,
                    .postToWeibo,
                    .postToVimeo,
                    .postToFlickr,
                    .postToTencentWeibo,
                    .assignToContact,
                    .saveToCameraRoll,
                    .addToReadingList,
                    .airDrop,
                    .mail,
                    .copyToPasteboard,
                    .print
                ]

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    topController.present(activityVC, animated: true)
                }

                dismiss()
            }
        }
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

        let subject = "Check out this home on Housers!"
        let body = shareText

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let mailURL = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailURL) {
            UIApplication.shared.open(url)
            dismiss()
        }
    }

    func showSystemShareSheet() {
        trackShare()

        // Load the image to share along with text
        Task {
            var itemsToShare: [Any] = [shareText, shareURL]

            // Download and add image if available
            if let imageUrl = home.imageUrls.first,
               let url = URL(string: imageUrl),
               let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                itemsToShare.insert(image, at: 0) // Add image first
            }

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: itemsToShare,
                    applicationActivities: nil
                )

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    // Find the top-most view controller
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    topController.present(activityVC, animated: true)
                }

                dismiss()
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

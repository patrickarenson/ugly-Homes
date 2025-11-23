//
//  OnboardingView.swift
//  Ugly Homes
//
//  Onboarding flow to capture user information immediately after signup
//

import SwiftUI
import PhotosUI

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

    let userId: UUID
    let existingUsername: String

    let userTypeOptions = [
        ("realtor", "Realtor/Broker", "Licensed real estate agent"),
        ("professional", "Real Estate Professional", "Lender, appraiser, title, etc."),
        ("buyer", "Home Buyer", "Looking to buy or rent"),
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
                    userTypeOptions: userTypeOptions
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
            withAnimation {
                currentStep += 1
            }
        } else {
            // Final step - save everything
            completeOnboarding()
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

// MARK: - User Type & Location Step
struct UserTypeLocationStep: View {
    @Binding var selectedUserTypes: Set<String>
    @Binding var location: String
    let username: String
    let userTypeOptions: [(String, String, String)]

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

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        TextField("e.g., San Francisco, CA", text: $location)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
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

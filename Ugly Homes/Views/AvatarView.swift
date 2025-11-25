import SwiftUI

/// Reusable avatar component that displays:
/// - User's uploaded photo if available
/// - First letter of username in a colored circle as fallback
struct AvatarView: View {
    let avatarUrl: String?
    let username: String
    let size: CGFloat

    var body: some View {
        if let avatarUrl = avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
            // Display uploaded photo with cache-busting timestamp
            let urlWithCache = URL(string: "\(avatarUrl)?t=\(Date().timeIntervalSince1970)")
            AsyncImage(url: urlWithCache ?? url) { phase in
                switch phase {
                case .empty:
                    // Show nothing while loading (image loads fast from cache)
                    Color.clear
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    // Only show initial avatar if image fails to load
                    initialAvatar
                @unknown default:
                    initialAvatar
                }
            }
        } else {
            // Show initial when no photo
            initialAvatar
        }
    }

    private var initialAvatar: some View {
        Circle()
            .fill(avatarGradient)
            .frame(width: size, height: size)
            .overlay(
                Text(userInitial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private var userInitial: String {
        guard let firstChar = username.first else { return "?" }
        return String(firstChar).uppercased()
    }

    /// Generate a consistent color based on username
    private var avatarGradient: LinearGradient {
        let colors = generateColors(from: username)
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Generate consistent colors based on username hash
    private func generateColors(from username: String) -> [Color] {
        // Create a hash from the username
        let hash = username.lowercased().unicodeScalars.reduce(0) { result, scalar in
            return result &+ Int(scalar.value)
        }

        // Use hash to pick from predefined color pairs
        let colorPairs: [([Color], [Color])] = [
            // Houser orange
            ([Color(red: 1.0, green: 0.65, blue: 0.3), Color(red: 1.0, green: 0.45, blue: 0.2)],
             [Color(red: 1.0, green: 0.45, blue: 0.2), Color(red: 1.0, green: 0.65, blue: 0.3)]),
            // Blue
            ([Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.3, blue: 0.8)],
             [Color(red: 0.1, green: 0.3, blue: 0.8), Color(red: 0.2, green: 0.5, blue: 1.0)]),
            // Purple
            ([Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.4, green: 0.2, blue: 0.7)],
             [Color(red: 0.4, green: 0.2, blue: 0.7), Color(red: 0.6, green: 0.3, blue: 0.9)]),
            // Green
            ([Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.1, green: 0.5, blue: 0.3)],
             [Color(red: 0.1, green: 0.5, blue: 0.3), Color(red: 0.2, green: 0.7, blue: 0.4)]),
            // Red/Pink
            ([Color(red: 0.9, green: 0.3, blue: 0.4), Color(red: 0.7, green: 0.2, blue: 0.3)],
             [Color(red: 0.7, green: 0.2, blue: 0.3), Color(red: 0.9, green: 0.3, blue: 0.4)]),
            // Teal
            ([Color(red: 0.2, green: 0.7, blue: 0.7), Color(red: 0.1, green: 0.5, blue: 0.6)],
             [Color(red: 0.1, green: 0.5, blue: 0.6), Color(red: 0.2, green: 0.7, blue: 0.7)])
        ]

        let pairIndex = abs(hash) % colorPairs.count
        let gradientVariant = abs(hash / colorPairs.count) % 2

        return gradientVariant == 0 ? colorPairs[pairIndex].0 : colorPairs[pairIndex].1
    }
}

// MARK: - Preview
struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // With photo
            AvatarView(
                avatarUrl: "https://example.com/photo.jpg",
                username: "john",
                size: 80
            )

            // Without photo - shows initial
            AvatarView(
                avatarUrl: nil,
                username: "alice",
                size: 80
            )

            // Different sizes
            HStack(spacing: 16) {
                AvatarView(avatarUrl: nil, username: "bob", size: 32)
                AvatarView(avatarUrl: nil, username: "carol", size: 48)
                AvatarView(avatarUrl: nil, username: "dave", size: 64)
                AvatarView(avatarUrl: nil, username: "eve", size: 80)
            }

            // Different usernames show different colors
            HStack(spacing: 16) {
                AvatarView(avatarUrl: nil, username: "amy", size: 48)
                AvatarView(avatarUrl: nil, username: "ben", size: 48)
                AvatarView(avatarUrl: nil, username: "cam", size: 48)
                AvatarView(avatarUrl: nil, username: "dan", size: 48)
                AvatarView(avatarUrl: nil, username: "eli", size: 48)
            }
        }
        .padding()
    }
}

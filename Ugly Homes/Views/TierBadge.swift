//
//  TierBadge.swift
//  Ugly Homes
//
//  Subtle tier indicator - modern, minimal design
//  Note: Blue verified badge remains exclusive
//

import SwiftUI

enum UserTier: String {
    case newcomer = "newcomer"
    case contributor = "contributor"
    case localExpert = "local_expert"
    case neighborhoodPro = "neighborhood_pro"
    case superHouser = "super_houser"

    var color: Color {
        switch self {
        case .newcomer:
            return .clear
        case .contributor:
            return Color(red: 0.72, green: 0.45, blue: 0.20) // Bronze
        case .localExpert:
            return Color(red: 0.60, green: 0.60, blue: 0.65) // Silver
        case .neighborhoodPro:
            return Color(red: 0.85, green: 0.65, blue: 0.13) // Gold
        case .superHouser:
            return Color(red: 0.38, green: 0.71, blue: 0.71) // Teal/Platinum
        }
    }

    var shortName: String {
        switch self {
        case .newcomer: return ""
        case .contributor: return "C"
        case .localExpert: return "E"
        case .neighborhoodPro: return "P"
        case .superHouser: return "S"
        }
    }

    var displayName: String {
        switch self {
        case .newcomer: return "Newcomer"
        case .contributor: return "Contributor"
        case .localExpert: return "Local Expert"
        case .neighborhoodPro: return "Pro"
        case .superHouser: return "Super Houser"
        }
    }

    var minPoints: Int {
        switch self {
        case .newcomer: return 0
        case .contributor: return 100
        case .localExpert: return 500
        case .neighborhoodPro: return 2000
        case .superHouser: return 10000
        }
    }

    static func from(string: String?) -> UserTier {
        guard let tierString = string else { return .newcomer }
        return UserTier(rawValue: tierString) ?? .newcomer
    }
}

/// Minimal tier badge - small dot or letter indicator
struct TierBadge: View {
    let tier: String?
    var size: CGFloat = 12

    private var userTier: UserTier {
        UserTier.from(string: tier)
    }

    var body: some View {
        if userTier != .newcomer {
            // Simple colored dot
            Circle()
                .fill(userTier.color)
                .frame(width: size * 0.6, height: size * 0.6)
        }
    }
}

/// Clean tier progress bar for profile
struct TierLabel: View {
    let tier: String?
    let points: Int?

    private var userTier: UserTier {
        UserTier.from(string: tier)
    }

    private var nextTier: UserTier? {
        switch userTier {
        case .newcomer: return .contributor
        case .contributor: return .localExpert
        case .localExpert: return .neighborhoodPro
        case .neighborhoodPro: return .superHouser
        case .superHouser: return nil
        }
    }

    private var progressToNextTier: Double {
        guard let next = nextTier else { return 1.0 }
        let currentPoints = points ?? 0
        let currentMin = userTier.minPoints
        let nextMin = next.minPoints
        let progress = Double(currentPoints - currentMin) / Double(nextMin - currentMin)
        return min(max(progress, 0), 1)
    }

    private var pointsToNext: Int {
        guard let next = nextTier else { return 0 }
        return max(0, next.minPoints - (points ?? 0))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track with border
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                        .frame(height: 8)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: nextTier != nil
                                    ? [userTier.color, nextTier!.color.opacity(0.8)]
                                    : [userTier.color, userTier.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progressToNextTier, 8), height: 8)
                }
            }
            .frame(height: 8)

            // Labels
            HStack {
                Text(userTier.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(userTier == .newcomer ? .secondary : userTier.color)

                Spacer()

                if let next = nextTier {
                    Text("\(pointsToNext) pts to \(next.displayName)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(userTier.color)
                        Text("Max Level")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        // Inline badges next to username
        VStack(alignment: .leading, spacing: 8) {
            Text("Next to username:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Text("@contributor")
                    .fontWeight(.semibold)
                TierBadge(tier: "contributor")
            }

            HStack(spacing: 4) {
                Text("@pro")
                    .fontWeight(.semibold)
                TierBadge(tier: "neighborhood_pro")
            }

            HStack(spacing: 4) {
                Text("@superhouser")
                    .fontWeight(.semibold)
                TierBadge(tier: "super_houser")
            }
        }

        Divider()

        // Profile progress bars (3/4 width simulation)
        VStack(spacing: 16) {
            Text("Profile progress:")
                .font(.caption)
                .foregroundColor(.secondary)

            TierLabel(tier: "newcomer", points: 45)
                .padding(.horizontal, 40)

            TierLabel(tier: "contributor", points: 250)
                .padding(.horizontal, 40)

            TierLabel(tier: "local_expert", points: 1200)
                .padding(.horizontal, 40)

            TierLabel(tier: "neighborhood_pro", points: 5500)
                .padding(.horizontal, 40)

            TierLabel(tier: "super_houser", points: 15000)
                .padding(.horizontal, 40)
        }
    }
    .padding()
}

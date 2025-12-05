//
//  DiscoverMoreView.swift
//  Ugly Homes
//
//  "Discover More Homes" button that imports properties from user's market
//

import SwiftUI

struct DiscoverMoreView: View {
    @State private var isImporting = false
    @State private var importCount = 0
    @State private var importMessage = ""
    @State private var loadingMessageIndex = 0
    @State private var loadingMessageTimer: Timer?

    private let maxImportsPerSession = 10
    private let loadingMessages = [
        "Searching neighborhoods...",
        "Checking new listings...",
        "Finding hidden gems...",
        "Exploring the market...",
        "Scanning for deals...",
        "Almost there...",
        "Just a bit longer...",
        "Worth the wait..."
    ]

    var onPropertiesImported: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)

            if isImporting {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(importMessage.isEmpty ? "Finding new properties..." : importMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
            } else if importCount >= maxImportsPerSession {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("You've discovered lots of new homes today!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Check back tomorrow for more")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    Text("Want to see more?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)

                    Button(action: {
                        discoverMoreProperties()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Discover More Homes")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                    }

                    if importCount > 0 {
                        Text("\(maxImportsPerSession - importCount) discoveries remaining today")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .padding(.horizontal, 20)
    }

    private func startLoadingMessageRotation() {
        loadingMessageIndex = 0
        importMessage = loadingMessages[0]

        loadingMessageTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            loadingMessageIndex = (loadingMessageIndex + 1) % loadingMessages.count
            importMessage = loadingMessages[loadingMessageIndex]
        }
    }

    private func stopLoadingMessageRotation() {
        loadingMessageTimer?.invalidate()
        loadingMessageTimer = nil
    }

    private func discoverMoreProperties() {
        guard importCount < maxImportsPerSession else { return }
        guard !isImporting else { return }

        isImporting = true
        startLoadingMessageRotation()

        Task {
            do {
                // Get user's market from profile
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("*")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value

                guard let market = profile.market, !market.isEmpty else {
                    await MainActor.run {
                        stopLoadingMessageRotation()
                        importMessage = "Please set your market in your profile"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isImporting = false
                            importMessage = ""
                        }
                    }
                    return
                }

                // Determine primary user type from profile
                let userType = getPrimaryUserType(from: profile.userTypes)

                // Call the onboarding-import API endpoint
                let apiUrl = "https://api.housers.us/api/onboarding-import"

                var request = URLRequest(url: URL(string: apiUrl)!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "location": market,
                    "userType": userType,
                    "userId": userId.uuidString,
                    "fetchDescriptions": true  // Ensure descriptions and tags are generated
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                await MainActor.run {
                    stopLoadingMessageRotation()
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let posted = json["posted"] as? Int {
                        await MainActor.run {
                            if posted > 0 {
                                importMessage = "Found \(posted) new properties!"
                            } else {
                                importMessage = "All caught up! No new listings right now."
                            }
                            importCount += 1
                        }
                    } else {
                        await MainActor.run {
                            importMessage = "Feed refreshed!"
                            importCount += 1
                        }
                    }

                    // Wait a moment then trigger refresh
                    try await Task.sleep(nanoseconds: 1_500_000_000)

                    await MainActor.run {
                        isImporting = false
                        importMessage = ""
                        onPropertiesImported()
                    }
                } else {
                    await MainActor.run {
                        importMessage = "Couldn't find new properties"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isImporting = false
                            importMessage = ""
                        }
                    }
                }
            } catch {
                print("❌ Error discovering properties: \(error)")
                await MainActor.run {
                    stopLoadingMessageRotation()
                    importMessage = "Something went wrong"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isImporting = false
                        importMessage = ""
                    }
                }
            }
        }
    }

    /// Get primary user type from profile's userTypes array, defaulting to "browsing"
    private func getPrimaryUserType(from userTypes: [String]?) -> String {
        guard let types = userTypes, !types.isEmpty else {
            return "browsing"
        }

        // Priority order for user types
        if types.contains("buyer") {
            return "buyer"
        } else if types.contains("renter") {
            return "renter"
        } else if types.contains("investor") {
            return "investor"
        } else if types.contains("realtor") {
            return "realtor"
        } else if types.contains("professional") {
            return "professional"
        } else if types.contains("designer") {
            return "designer"
        } else {
            return "browsing"
        }
    }
}

#Preview {
    DiscoverMoreView(onPropertiesImported: {})
}

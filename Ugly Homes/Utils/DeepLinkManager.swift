//
//  DeepLinkManager.swift
//  Ugly Homes
//
//  Handles deep linking for shared posts
//

import Foundation
import SwiftUI
import Auth

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingHomeId: UUID? = nil
    @Published var shouldShowPost: Bool = false
    @Published var pendingUsername: String? = nil
    @Published var shouldShowProfile: Bool = false

    private init() {
        // Load any pending home ID from UserDefaults (in case app was closed)
        if let savedId = UserDefaults.standard.string(forKey: "pendingDeepLinkHomeId"),
           let uuid = UUID(uuidString: savedId) {
            pendingHomeId = uuid
        }

        // Load any pending username from UserDefaults
        if let savedUsername = UserDefaults.standard.string(forKey: "pendingDeepLinkUsername") {
            pendingUsername = savedUsername
        }
    }

    /// Handle an incoming URL (e.g., housers://property/123 or https://housers.us/@username)
    func handleURL(_ url: URL) {
        print("🔗 Deep link received: \(url.absoluteString)")
        print("🔗 URL scheme: \(url.scheme ?? "none")")
        print("🔗 URL host: \(url.host ?? "none")")
        print("🔗 URL path: \(url.path)")

        // Check if this is an OAuth callback
        if url.host == "oauth-callback" || url.path.contains("oauth-callback") {
            print("🔑 OAuth callback detected, handling session")
            print("🔑 Full OAuth URL: \(url.absoluteString)")
            Task {
                do {
                    // Parse tokens from URL fragment (Implicit Flow)
                    // URL format: houser://oauth-callback#access_token=...&refresh_token=...
                    let session: Session

                    if let fragment = url.fragment, fragment.contains("access_token") {
                        // Implicit Flow - tokens in fragment
                        print("🔑 Parsing tokens from URL fragment (Implicit Flow)")
                        let params = fragment.components(separatedBy: "&")
                            .reduce(into: [String: String]()) { (dict: inout [String: String], param: String) in
                                let parts = param.components(separatedBy: "=")
                                if parts.count == 2 {
                                    dict[parts[0]] = parts[1]
                                }
                            }

                        guard let accessToken = params["access_token"],
                              let refreshToken = params["refresh_token"] else {
                            throw NSError(domain: "OAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing tokens in callback"])
                        }

                        print("✅ Tokens extracted, setting session...")
                        session = try await SupabaseManager.shared.client.auth.setSession(
                            accessToken: accessToken,
                            refreshToken: refreshToken
                        )
                    } else {
                        // PKCE Flow - code in query parameters
                        print("🔑 Using PKCE flow")
                        session = try await SupabaseManager.shared.client.auth.session(from: url)
                    }
                    print("✅ OAuth session established successfully")
                    print("✅ User ID: \(session.user.id)")

                    // Detect provider type
                    let provider = session.user.appMetadata["provider"]?.stringValue ?? "unknown"
                    print("🔑 OAuth Provider: \(provider)")

                    // For OAuth users, create username from email or provider data
                    let email = session.user.email ?? ""
                    var defaultUsername: String

                    if !email.isEmpty {
                        // Use email prefix if available
                        defaultUsername = email.components(separatedBy: "@").first?.lowercased() ?? "user\(session.user.id.uuidString.prefix(8))"
                    } else {
                        // Apple users can hide email - use provider + unique ID
                        defaultUsername = "\(provider)user\(session.user.id.uuidString.prefix(8))".lowercased()
                    }

                    print("🏷️ Generated username: \(defaultUsername)")

                    // Check if profile exists, if not create one
                    let profiles: [Profile] = try await SupabaseManager.shared.client
                        .from("profiles")
                        .select()
                        .eq("id", value: session.user.id.uuidString)
                        .execute()
                        .value

                    if profiles.isEmpty {
                        print("📝 Creating profile for OAuth user")
                        // Create profile for OAuth user
                        struct NewProfile: Encodable {
                            let id: String
                            let username: String
                            let full_name: String?
                        }

                        // Extract full_name from userMetadata if available
                        // Apple and Google may provide name differently
                        var fullName: String? = nil

                        // Try full_name first (Google)
                        if case .string(let name) = session.user.userMetadata["full_name"] {
                            fullName = name
                        }
                        // Try name field (Apple)
                        else if case .string(let name) = session.user.userMetadata["name"] {
                            fullName = name
                        }
                        // Try combining first + last name (Apple can provide these separately)
                        else {
                            var nameParts: [String] = []
                            if case .string(let firstName) = session.user.userMetadata["first_name"] {
                                nameParts.append(firstName)
                            }
                            if case .string(let lastName) = session.user.userMetadata["last_name"] {
                                nameParts.append(lastName)
                            }
                            if !nameParts.isEmpty {
                                fullName = nameParts.joined(separator: " ")
                            }
                        }

                        print("👤 Full name: \(fullName ?? "not provided")")

                        let newProfile = NewProfile(
                            id: session.user.id.uuidString,
                            username: defaultUsername,
                            full_name: fullName
                        )

                        try await SupabaseManager.shared.client
                            .from("profiles")
                            .insert(newProfile)
                            .execute()

                        print("✅ Profile created for OAuth user: \(defaultUsername)")
                    }

                    // Save terms acceptance for OAuth users
                    struct TermsData: Encodable {
                        let user_id: String
                        let accepted_at: String
                        let terms_version: String
                    }

                    let termsData = TermsData(
                        user_id: session.user.id.uuidString,
                        accepted_at: ISO8601DateFormatter().string(from: Date()),
                        terms_version: "1.0"
                    )

                    try await SupabaseManager.shared.client
                        .from("terms_acceptance")
                        .upsert(termsData)
                        .execute()

                    print("✅ Terms acceptance saved for OAuth user")

                    // Post notification to trigger auth state change
                    await MainActor.run {
                        NotificationCenter.default.post(name: .supabaseAuthStateChanged, object: nil)

                        // Request push notification permission
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                print("✅ Push notifications enabled")
                            } else {
                                print("⚠️ Push notifications declined")
                            }
                        }
                    }
                } catch {
                    print("❌ OAuth callback error: \(error)")
                }
            }
            return
        }

        // Parse URL - handle both custom scheme (housers://) and universal links (https://)
        let pathComponents = url.pathComponents
        print("🔗 Path components: \(pathComponents)")

        // Check for profile URLs first
        if let username = extractUsername(from: url, pathComponents: pathComponents) {
            print("✅ Parsed username: \(username)")

            // Save the username and trigger navigation
            pendingUsername = username
            shouldShowProfile = true

            // Persist to UserDefaults in case user needs to log in
            UserDefaults.standard.set(username, forKey: "pendingDeepLinkUsername")
            return
        }

        // Extract home ID from path
        var homeIdString: String? = nil

        // For housers://home/UUID or housers://property/UUID format
        if url.scheme == "housers" {
            // Host is "home" or "property" and path contains the UUID
            if (url.host == "home" || url.host == "property"), let path = url.pathComponents.last {
                homeIdString = path
            } else if pathComponents.count >= 2 {
                // Sometimes it's parsed as path: "/home/UUID" or "/property/UUID"
                homeIdString = pathComponents[pathComponents.count - 1]
            }
        }
        // For https://housers.us/home/UUID or https://housers.us/property/UUID format
        else if pathComponents.count >= 3 && (pathComponents[1] == "home" || pathComponents[1] == "property") {
            homeIdString = pathComponents[2]
        }

        guard let idString = homeIdString,
              let homeId = UUID(uuidString: idString) else {
            print("❌ Invalid deep link format - couldn't extract home ID or username")
            return
        }

        print("✅ Parsed home ID: \(homeId)")

        // Save the home ID and trigger navigation
        pendingHomeId = homeId
        shouldShowPost = true

        // Persist to UserDefaults in case user needs to log in
        UserDefaults.standard.set(homeId.uuidString, forKey: "pendingDeepLinkHomeId")
    }

    /// Extract username from various URL formats
    private func extractUsername(from url: URL, pathComponents: [String]) -> String? {
        // For housers://user/username or housers://@username format
        if url.scheme == "housers" {
            // housers://user/username
            if url.host == "user", let username = pathComponents.last, !username.isEmpty && username != "/" {
                return username.lowercased()
            }
            // housers://@username (@ is the host)
            if let host = url.host, host.hasPrefix("@") {
                return String(host.dropFirst()).lowercased()
            }
            // housers://username (username is the host without @)
            if let host = url.host, !["home", "property", "user"].contains(host), UUID(uuidString: host) == nil {
                return host.lowercased()
            }
        }

        // For https://housers.us/@username or https://housers.us/user/username format
        if pathComponents.count >= 2 {
            let lastComponent = pathComponents[pathComponents.count - 1]

            // https://housers.us/@username
            if lastComponent.hasPrefix("@") && lastComponent.count > 1 {
                return String(lastComponent.dropFirst()).lowercased()
            }

            // https://housers.us/user/username
            if pathComponents.count >= 3 && pathComponents[1] == "user" {
                return pathComponents[2].lowercased()
            }
        }

        return nil
    }

    /// Clear the pending deep link after navigation
    func clearPendingLink() {
        pendingHomeId = nil
        shouldShowPost = false
        pendingUsername = nil
        shouldShowProfile = false
        UserDefaults.standard.removeObject(forKey: "pendingDeepLinkHomeId")
        UserDefaults.standard.removeObject(forKey: "pendingDeepLinkUsername")
        print("🗑️ Cleared pending deep link")
    }

    /// Check if user just logged in and has pending deep link
    func handlePostLogin() {
        if let pendingId = pendingHomeId {
            print("✅ User logged in, navigating to post: \(pendingId)")
            shouldShowPost = true
        }
        if let username = pendingUsername {
            print("✅ User logged in, navigating to profile: @\(username)")
            shouldShowProfile = true
        }
    }
}

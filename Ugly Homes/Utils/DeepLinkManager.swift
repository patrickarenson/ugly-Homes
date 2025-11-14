//
//  DeepLinkManager.swift
//  Ugly Homes
//
//  Handles deep linking for shared posts
//

import Foundation
import SwiftUI

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

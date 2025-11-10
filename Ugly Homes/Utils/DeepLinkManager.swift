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

    private init() {
        // Load any pending home ID from UserDefaults (in case app was closed)
        if let savedId = UserDefaults.standard.string(forKey: "pendingDeepLinkHomeId"),
           let uuid = UUID(uuidString: savedId) {
            pendingHomeId = uuid
        }
    }

    /// Handle an incoming URL (e.g., housers://property/123 or https://housers.us/property/123)
    func handleURL(_ url: URL) {
        print("🔗 Deep link received: \(url.absoluteString)")
        print("🔗 URL scheme: \(url.scheme ?? "none")")
        print("🔗 URL host: \(url.host ?? "none")")
        print("🔗 URL path: \(url.path)")

        // Parse URL - handle both custom scheme (housers://) and universal links (https://)
        let pathComponents = url.pathComponents
        print("🔗 Path components: \(pathComponents)")

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
            print("❌ Invalid deep link format - couldn't extract home ID")
            return
        }

        print("✅ Parsed home ID: \(homeId)")

        // Save the home ID and trigger navigation
        pendingHomeId = homeId
        shouldShowPost = true

        // Persist to UserDefaults in case user needs to log in
        UserDefaults.standard.set(homeId.uuidString, forKey: "pendingDeepLinkHomeId")
    }

    /// Clear the pending deep link after navigation
    func clearPendingLink() {
        pendingHomeId = nil
        shouldShowPost = false
        UserDefaults.standard.removeObject(forKey: "pendingDeepLinkHomeId")
        print("🗑️ Cleared pending deep link")
    }

    /// Check if user just logged in and has pending deep link
    func handlePostLogin() {
        if let pendingId = pendingHomeId {
            print("✅ User logged in, navigating to post: \(pendingId)")
            shouldShowPost = true
        }
    }
}

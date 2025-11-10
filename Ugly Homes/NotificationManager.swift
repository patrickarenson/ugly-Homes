//
//  NotificationManager.swift
//  Ugly Homes
//
//  Push Notification Manager
//

import Foundation
@preconcurrency import UserNotifications
import UIKit
import Supabase

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var deviceToken: String?
    @Published var permissionGranted = false

    private override init() {
        super.init()
    }

    // MARK: - Request Permission

    /// Request push notification permission from user
    nonisolated func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.permissionGranted = granted

                if let error = error {
                    print("❌ Push notification permission error: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if granted {
                    print("✅ Push notification permission granted")
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                    completion(true)
                } else {
                    print("⚠️ Push notification permission denied")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Device Token Management

    /// Called when device token is successfully registered with APNs
    nonisolated func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Task { @MainActor in
            self.deviceToken = tokenString
            print("✅ Device token registered: \(tokenString)")

            // Save token to Supabase
            await self.saveDeviceToken(tokenString)
        }
    }

    /// Called when device token registration fails
    nonisolated func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Save device token to Supabase
    private func saveDeviceToken(_ token: String) async {
        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            print("❌ Cannot save device token: No user logged in")
            return
        }

        do {
            // Check if token already exists
            let existing: [DeviceToken] = try await SupabaseManager.shared.client
                .from("device_tokens")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("device_token", value: token)
                .execute()
                .value

            if existing.isEmpty {
                // Insert new token
                let newToken = DeviceToken(
                    userId: userId.uuidString,
                    deviceToken: token,
                    deviceType: "ios"
                )

                try await SupabaseManager.shared.client
                    .from("device_tokens")
                    .insert(newToken)
                    .execute()

                print("✅ Device token saved to Supabase")
            } else {
                // Update existing token (refresh timestamp)
                try await SupabaseManager.shared.client
                    .from("device_tokens")
                    .update(["updated_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("user_id", value: userId.uuidString)
                    .eq("device_token", value: token)
                    .execute()

                print("✅ Device token updated in Supabase")
            }
        } catch {
            print("❌ Error saving device token to Supabase: \(error)")
        }
    }

    /// Remove device token from Supabase (call on logout)
    func removeDeviceToken() async {
        guard let token = deviceToken,
              let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            return
        }

        do {
            try await SupabaseManager.shared.client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("device_token", value: token)
                .execute()

            print("✅ Device token removed from Supabase")

            DispatchQueue.main.async {
                self.deviceToken = nil
            }
        } catch {
            print("❌ Error removing device token: \(error)")
        }
    }

    // MARK: - Check Permission Status

    /// Check current notification permission status
    func checkPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        DispatchQueue.main.async {
            self.permissionGranted = settings.authorizationStatus == .authorized
        }

        return settings.authorizationStatus == .authorized
    }

    // MARK: - Badge Management

    /// Update app badge count
    func updateBadgeCount(_ count: Int) {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    /// Clear app badge
    func clearBadge() {
        updateBadgeCount(0)
    }
}

// MARK: - Device Token Model

struct DeviceToken: Codable {
    let userId: String
    let deviceToken: String
    let deviceType: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceToken = "device_token"
        case deviceType = "device_type"
    }
}

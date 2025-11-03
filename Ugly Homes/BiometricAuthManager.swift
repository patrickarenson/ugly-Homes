//
//  BiometricAuthManager.swift
//  Ugly Homes
//
//  Biometric Authentication Manager
//

import Foundation
import LocalAuthentication
import Security

class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private init() {}

    // Check if biometric authentication is available
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    // Authenticate with biometrics
    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"

        let reason = "Authenticate to access Housers"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            throw error
        }
    }

    // MARK: - Keychain Storage

    func saveCredentials(email: String, password: String) -> Bool {
        let emailData = Data(email.utf8)
        let passwordData = Data(password.utf8)

        // Save email
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "user_email",
            kSecValueData as String: emailData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing email
        SecItemDelete(emailQuery as CFDictionary)

        // Save new email
        let emailStatus = SecItemAdd(emailQuery as CFDictionary, nil)

        // Save password
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "user_password",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing password
        SecItemDelete(passwordQuery as CFDictionary)

        // Save new password
        let passwordStatus = SecItemAdd(passwordQuery as CFDictionary, nil)

        return emailStatus == errSecSuccess && passwordStatus == errSecSuccess
    }

    func getCredentials() -> (email: String, password: String)? {
        // Get email
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "user_email",
            kSecReturnData as String: true
        ]

        var emailItem: CFTypeRef?
        let emailStatus = SecItemCopyMatching(emailQuery as CFDictionary, &emailItem)

        guard emailStatus == errSecSuccess,
              let emailData = emailItem as? Data,
              let email = String(data: emailData, encoding: .utf8) else {
            return nil
        }

        // Get password
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "user_password",
            kSecReturnData as String: true
        ]

        var passwordItem: CFTypeRef?
        let passwordStatus = SecItemCopyMatching(passwordQuery as CFDictionary, &passwordItem)

        guard passwordStatus == errSecSuccess,
              let passwordData = passwordItem as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }

        return (email, password)
    }

    func deleteCredentials() {
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "user_email"
        ]
        SecItemDelete(emailQuery as CFDictionary)

        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "user_password"
        ]
        SecItemDelete(passwordQuery as CFDictionary)
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID

    var icon: String {
        switch self {
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .none:
            return ""
        }
    }

    var name: String {
        switch self {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .none:
            return ""
        }
    }
}

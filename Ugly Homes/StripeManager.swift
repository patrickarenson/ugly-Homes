//
//  StripeManager.swift
//  Ugly Homes
//
//  Stripe Payment Integration for Open House Feature ($5)
//

import Foundation
import UIKit
import StripePaymentSheet

class StripeManager: ObservableObject {
    static let shared = StripeManager()

    // MARK: - Configuration
    // Set to false for production, true for testing
    private let useTestMode = true

    // Stripe publishable keys from realtorDocs account
    private let livePublishableKey = "pk_live_51IQ4KFINuCqfox5ANOT1zQgE5WDR8mDAKixO5wP80hu6CgHLbi6zi04tDBW8WiYPhYlBOPZYcmOIWIXzPiGXvC5H00GUzwaHNw"
    private let testPublishableKey = "pk_test_51IQ4KFINuCqfox5Aw7pPA1TcK2kTYve8mB2wm7zo13detBUg6c1eeZgnrWa8yKi1ltZjvkH5i9ZjLbD1yQas63eJ00Hg9v0Hbq"

    private var publishableKey: String {
        return useTestMode ? testPublishableKey : livePublishableKey
    }

    // Payment configuration
    private let openHousePrice: Int = 500 // $5.00 in cents

    private init() {
        // Configure Stripe with the appropriate key
        STPAPIClient.shared.publishableKey = publishableKey
        print("🔑 Stripe configured in \(useTestMode ? "TEST" : "LIVE") mode")
    }

    /// Create a payment intent for Open House feature ($5)
    func createPaymentIntent(userId: String, homeId: String) async throws -> String {
        // Call Supabase Edge Function to create payment intent
        let url = URL(string: "https://pgezrygzubjieqfzyccy.supabase.co/functions/v1/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // IMPORTANT: Add authorization header for Edge Function access
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MzE5NjcsImV4cCI6MjA3NzQwNzk2N30.-AK_lNlPfjdPCyXP2KySnFFZ3D_u5UbczXmcOFD6AA8"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "amount": openHousePrice,
            "currency": "usd",
            "userId": userId,
            "homeId": homeId,
            "description": "Ugly Homes - Open House Feature"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🌐 Calling Edge Function: create-payment-intent")
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response status
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Edge Function response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Edge Function error: \(errorText)")
                throw NSError(domain: "StripeManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
            }
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let clientSecret = json?["clientSecret"] as? String else {
            throw NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get client secret from Edge Function"])
        }

        print("✅ Got client secret from Edge Function")
        return clientSecret
    }

    /// Present the Stripe payment sheet
    func presentPaymentSheet(clientSecret: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🎨 Setting up payment sheet configuration...")

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Ugly Homes"

        // Optional: Disable Apple Pay if merchant ID isn't set up
        // configuration.applePay = .init(merchantId: "merchant.com.homechat.app", merchantCountryCode: "US")

        configuration.defaultBillingDetails.name = ""
        configuration.allowsDelayedPaymentMethods = false

        print("💳 Creating PaymentSheet with client secret...")
        let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)

        // Get the topmost view controller for presenting the payment sheet
        print("🔍 Looking for topmost view controller...")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("❌ No window scene found")
            completion(.failure(NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No window scene found"])))
            return
        }

        print("🪟 Window scene found: \(windowScene)")

        guard let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No root view controller found in window scene")
            completion(.failure(NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])))
            return
        }

        // Get the topmost presented view controller (important for sheets)
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        print("✅ Topmost view controller found: \(type(of: topController))")
        print("🎬 Presenting payment sheet from: \(topController)")

        paymentSheet.present(from: topController) { result in
            print("📊 Payment sheet result received: \(result)")
            switch result {
            case .completed:
                print("✅ Payment completed!")
                completion(.success(()))
            case .failed(let error):
                print("❌ Payment failed: \(error.localizedDescription)")
                completion(.failure(error))
            case .canceled:
                print("⚠️ Payment canceled by user")
                completion(.failure(NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Payment canceled by user"])))
            }
        }
    }

    /// Convenience method to handle full payment flow
    func processOpenHousePayment(userId: String, homeId: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔵 StripeManager: Starting payment process for user: \(userId)")

        Task {
            do {
                print("🔵 StripeManager: Creating payment intent...")

                // Create payment intent
                let clientSecret = try await createPaymentIntent(userId: userId, homeId: homeId)

                print("🔵 StripeManager: Got client secret, presenting payment sheet...")

                // Present payment sheet
                await MainActor.run {
                    presentPaymentSheet(clientSecret: clientSecret) { result in
                        switch result {
                        case .success:
                            print("✅ StripeManager: Payment sheet completed successfully")
                            completion(.success(clientSecret))
                        case .failure(let error):
                            print("❌ StripeManager: Payment sheet failed: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                }
            } catch {
                print("❌ StripeManager: Error in payment process: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

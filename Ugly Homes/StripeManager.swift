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

    // Stripe publishable key from realtorDocs account (LIVE key)
    private let publishableKey = "pk_live_51IQ4KFINuCqfox5ANOT1zQgE5WDR8mDAKixO5wP80hu6CgHLbi6zi04tDBW8WiYPhYlBOPZYcmOIWIXzPiGXvC5H00GUzwaHNw"

    // Payment configuration
    private let openHousePrice: Int = 500 // $5.00 in cents

    private init() {
        // Configure Stripe (will be activated once Stripe SDK is added)
        // Uncomment this line after adding Stripe SDK to Xcode:
        STPAPIClient.shared.publishableKey = publishableKey
    }

    /// Create a payment intent for Open House feature ($5)
    func createPaymentIntent(userId: String, homeId: String) async throws -> String {
        // Call your backend to create payment intent
        // This should call a Supabase Edge Function or your own backend

        let url = URL(string: "https://pgezrygzubjieqfzyccy.supabase.co/functions/v1/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "amount": openHousePrice,
            "currency": "usd",
            "userId": userId,
            "homeId": homeId,
            "description": "Ugly Homes - Open House Feature"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let clientSecret = json?["clientSecret"] as? String else {
            throw NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get client secret"])
        }

        return clientSecret
    }

    /// Present the Stripe payment sheet
    func presentPaymentSheet(clientSecret: String, completion: @escaping (Result<Void, Error>) -> Void) {
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Ugly Homes"
        configuration.applePay = .init(merchantId: "merchant.com.homechat.app", merchantCountryCode: "US")
        configuration.defaultBillingDetails.name = ""
        configuration.allowsDelayedPaymentMethods = false

        let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)

        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            completion(.failure(NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])))
            return
        }

        paymentSheet.present(from: rootViewController) { result in
            switch result {
            case .completed:
                print("✅ Payment completed!")
                completion(.success(()))
            case .failed(let error):
                print("❌ Payment failed: \(error.localizedDescription)")
                completion(.failure(error))
            case .canceled:
                print("⚠️ Payment canceled")
                completion(.failure(NSError(domain: "StripeManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Payment canceled"])))
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

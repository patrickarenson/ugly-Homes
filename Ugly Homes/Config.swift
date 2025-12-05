//
//  Config.swift
//  Ugly Homes
//
//  API Configuration
//

import Foundation

/// Type alias for cleaner API access (Config.apiBaseURL)
typealias Config = APIConfig

struct APIConfig {
    // MARK: - Quick Import API

    // Change this to your Mac's IP address when developing
    // Find your IP: Open Terminal and run: ifconfig | grep "inet " | grep -v 127.0.0.1
    private static let developmentIP = "10.2.224.251" // UPDATE THIS when your IP changes
    private static let developmentPort = "3000"

    // Production URL - Custom domain for realtordocs API
    private static let productionURL = "https://api.housers.us"

    // Automatically use production URL for Release builds, development for Debug
    static var scrapingAPIBaseURL: String {
        #if DEBUG
        // TEMPORARY: Using production URL in debug mode since local server isn't running
        return productionURL
        // return "http://\(developmentIP):\(developmentPort)"
        #else
        return productionURL
        #endif
    }

    static var scrapingAPIEndpoint: String {
        return "\(scrapingAPIBaseURL)/api/scrape-listing"
    }

    // MARK: - General API Base URL

    /// Base URL for all API calls (onboarding, scraping, etc.)
    static var apiBaseURL: String {
        return scrapingAPIBaseURL
    }

    // MARK: - Helper

    /// Test if the scraping API is reachable
    static func testConnection(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: scrapingAPIBaseURL) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                completion(error == nil && (response as? HTTPURLResponse)?.statusCode != nil)
            }
        }.resume()
    }
}

//
//  Config.swift
//  Ugly Homes
//
//  API Configuration
//

import Foundation

struct APIConfig {
    // MARK: - Quick Import API

    // Change this to your Mac's IP address when developing
    // Find your IP: Open Terminal and run: ifconfig | grep "inet " | grep -v 127.0.0.1
    private static let developmentIP = "10.2.224.251" // UPDATE THIS when your IP changes
    private static let developmentPort = "3000"

    // For production, use your deployed server
    private static let productionURL = "https://your-api.com" // TODO: Set production URL

    // Automatically use production URL if available, otherwise development
    static var scrapingAPIBaseURL: String {
        #if DEBUG
        return "http://\(developmentIP):\(developmentPort)"
        #else
        return productionURL
        #endif
    }

    static var scrapingAPIEndpoint: String {
        return "\(scrapingAPIBaseURL)/api/scrape-listing"
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

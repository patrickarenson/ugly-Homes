//
//  Ugly_HomesApp.swift
//  Ugly Homes
//
//  Created by Patrick Arenson on 10/30/25.
//

import SwiftUI

@main
struct Ugly_HomesApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    // Handle deep links when app opens via URL
                    deepLinkManager.handleURL(url)
                }
        }
    }
}

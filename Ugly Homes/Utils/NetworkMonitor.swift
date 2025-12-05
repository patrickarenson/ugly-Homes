//
//  NetworkMonitor.swift
//  Ugly Homes
//
//  Monitors network connectivity and connection type (WiFi vs Cellular)
//

import Foundation
import Network

/// Monitors network status to optimize data usage
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = true
    @Published var isWiFi: Bool = false
    @Published var isCellular: Bool = false
    @Published var isExpensive: Bool = false // True for cellular/hotspot

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isWiFi = path.usesInterfaceType(.wifi)
                self?.isCellular = path.usesInterfaceType(.cellular)
                self?.isExpensive = path.isExpensive // True for metered connections

                #if DEBUG
                print("🌐 Network Status:")
                print("   Connected: \(path.status == .satisfied)")
                print("   WiFi: \(path.usesInterfaceType(.wifi))")
                print("   Cellular: \(path.usesInterfaceType(.cellular))")
                print("   Expensive: \(path.isExpensive)")
                #endif
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Returns true if we should fetch full quality/quantity data
    /// (WiFi connection that isn't expensive like a hotspot)
    var shouldFetchFullData: Bool {
        return isWiFi && !isExpensive
    }
}

//
//  MainTabView.swift
//  Ugly Homes
//
//  Main Tab Bar with Popular, Location, and Price views
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "flame.fill")
                        .padding(.top, 10)
                }

            LocationFeedView()
                .tabItem {
                    Image(systemName: "map.fill")
                        .padding(.top, 10)
                }

            PriceFeedView()
                .tabItem {
                    Image(systemName: "dollarsign.circle.fill")
                        .padding(.top, 10)
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                        .padding(.top, 10)
                }
        }
        .accentColor(.orange)
    }
}

#Preview {
    MainTabView()
}

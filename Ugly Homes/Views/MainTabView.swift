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
                        .padding(.top, 4)
                }

            LocationFeedView()
                .tabItem {
                    Image(systemName: "map.fill")
                        .padding(.top, 4)
                }

            PriceFeedView()
                .tabItem {
                    Image(systemName: "dollarsign.circle.fill")
                        .padding(.top, 4)
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                        .padding(.top, 4)
                }
        }
        .accentColor(.orange)
    }
}

#Preview {
    MainTabView()
}

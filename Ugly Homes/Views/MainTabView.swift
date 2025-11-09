//
//  MainTabView.swift
//  Ugly Homes
//
//  Main Tab Bar with Popular, Location, and Price views
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var unreadManager = UnreadMessagesManager()
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var deepLinkedHome: Home? = nil
    @State private var searchText = ""
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: "flame.fill")
                        .padding(.top, 10)
                }
                .tag(0)

            LocationFeedView()
                .tabItem {
                    Image(systemName: "map.fill")
                        .padding(.top, 10)
                }
                .tag(1)

            PriceFeedView()
                .tabItem {
                    Image(systemName: "dollarsign.circle.fill")
                        .padding(.top, 10)
                }
                .tag(2)

            // Messages tab - COMMENTED OUT for App Store submission
            // TODO: Re-enable once fully tested
//            MessagesView()
//                .environmentObject(unreadManager)
//                .tabItem {
//                    Image(systemName: "paperplane.fill")
//                        .padding(.top, 10)
//                }
//                .badge(unreadManager.totalUnreadCount)
//                .tag(3)

            NavigationView {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.circle.fill")
                    .padding(.top, 10)
                }
                .tag(3)
        }
        .accentColor(.orange)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SearchByTag"))) { notification in
            if let tag = notification.userInfo?["tag"] as? String {
                print("🏷️ Received SearchByTag notification: \(tag)")
                selectedTab = 0 // Switch to Feed tab
                // Post another notification for FeedView to pick up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SetSearchText"),
                        object: nil,
                        userInfo: ["searchText": tag]
                    )
                }
            }
        }
        .onAppear {
            unreadManager.startPolling()
            checkForDeepLink()
        }
        .onDisappear {
            unreadManager.stopPolling()
        }
        .onChange(of: deepLinkManager.shouldShowPost) { oldValue, newValue in
            if newValue {
                loadDeepLinkedPost()
            }
        }
        .fullScreenCover(item: $deepLinkedHome) { home in
            ZStack {
                ScrollView {
                    HomePostView(home: home, searchText: $searchText, showSoldOptions: false, preloadedUserId: nil)
                }
                .ignoresSafeArea(.all, edges: .bottom)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            deepLinkedHome = nil
                            deepLinkManager.clearPendingLink()
                        }) {
                            HStack {
                                Text("Close")
                                    .font(.system(size: 16))
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                        }
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    func checkForDeepLink() {
        // Check if user just logged in with a pending deep link
        if deepLinkManager.pendingHomeId != nil {
            deepLinkManager.handlePostLogin()
        }
    }

    func loadDeepLinkedPost() {
        guard let homeId = deepLinkManager.pendingHomeId else { return }

        Task {
            do {
                print("🔄 Loading deep linked post: \(homeId)")

                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("id", value: homeId.uuidString)
                    .execute()
                    .value

                if let home = response.first {
                    await MainActor.run {
                        deepLinkedHome = home
                        print("✅ Deep linked post loaded")
                    }
                } else {
                    print("❌ Deep linked post not found")
                    await MainActor.run {
                        deepLinkManager.clearPendingLink()
                    }
                }
            } catch {
                print("❌ Error loading deep linked post: \(error)")
                await MainActor.run {
                    deepLinkManager.clearPendingLink()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}

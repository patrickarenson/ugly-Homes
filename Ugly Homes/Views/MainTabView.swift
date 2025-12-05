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
    @State private var deepLinkedProfile: Profile? = nil
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var previousTabBeforeMap: Int = 0  // Track where user came from before going to map
    @State private var showOnboarding = false
    @State private var currentUserId: UUID?
    @State private var currentUsername: String?
    @State private var hasCheckedOnboarding = false

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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowHomeOnMap"))) { notification in
            if let homeId = notification.userInfo?["homeId"] as? UUID {
                print("🗺️ Received ShowHomeOnMap notification for: \(homeId)")
                // Save current tab before switching to map
                if selectedTab != 1 {
                    previousTabBeforeMap = selectedTab
                    print("📍 Saving previous tab: \(previousTabBeforeMap)")
                }
                selectedTab = 1 // Switch to Map tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReturnToTrendingFromMap"))) { notification in
            print("🔙 Returning to previous tab from map: \(previousTabBeforeMap)")
            selectedTab = previousTabBeforeMap // Switch back to wherever user came from

            // Give the tab switch a moment to complete, then notify the appropriate view to scroll
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let homeId = notification.userInfo?["homeId"] as? UUID {
                    print("📍 Forwarding homeId to view: \(homeId)")
                    // Send scroll notification - both FeedView and PriceFeedView can listen
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ScrollToHome"),
                        object: nil,
                        userInfo: ["homeId": homeId]
                    )
                }
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Clear map highlight when leaving map tab
            if oldTab == 1 && newTab != 1 {
                print("🗺️ Left map tab, clearing highlight")
                NotificationCenter.default.post(
                    name: NSNotification.Name("ClearMapHighlight"),
                    object: nil
                )
            }
        }
        .onAppear {
            unreadManager.startPolling()
            checkForDeepLink()
            checkOnboardingStatus()
        }
        .onDisappear {
            unreadManager.stopPolling()
        }
        .onChange(of: deepLinkManager.shouldShowPost) { oldValue, newValue in
            if newValue {
                loadDeepLinkedPost()
            }
        }
        .onChange(of: deepLinkManager.shouldShowProfile) { oldValue, newValue in
            if newValue {
                loadDeepLinkedProfile()
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
        .fullScreenCover(item: $deepLinkedProfile) { profile in
            NavigationView {
                ProfileView(viewingUserId: profile.id)
                    .navigationBarItems(trailing: Button(action: {
                        deepLinkedProfile = nil
                        deepLinkManager.clearPendingLink()
                    }) {
                        HStack {
                            Text("Close")
                                .font(.system(size: 16))
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                    })
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            if let userId = currentUserId, let username = currentUsername {
                OnboardingView(userId: userId, existingUsername: username)
            }
        }
    }

    func checkOnboardingStatus() {
        // Only check once per session
        guard !hasCheckedOnboarding else {
            print("ℹ️ Already checked onboarding for this session, skipping")
            return
        }

        hasCheckedOnboarding = true

        Task {
            do {
                // Get current user
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                currentUserId = userId

                // Get user's profile to check username and onboarding status
                let profiles: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value

                if let profile = profiles.first {
                    currentUsername = profile.username

                    // Check if user has completed onboarding (from database)
                    let hasCompletedOnboarding = profile.hasCompletedOnboarding ?? false

                    print("✅ Onboarding check: hasCompleted=\(hasCompletedOnboarding) for user \(userId.uuidString)")

                    if !hasCompletedOnboarding {
                        await MainActor.run {
                            // Small delay to let the UI settle
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showOnboarding = true
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error checking onboarding status: \(error)")
            }
        }
    }

    func checkForDeepLink() {
        // Check if user just logged in with a pending deep link
        if deepLinkManager.pendingHomeId != nil || deepLinkManager.pendingUsername != nil {
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

    func loadDeepLinkedProfile() {
        guard let username = deepLinkManager.pendingUsername else { return }

        Task {
            do {
                print("🔄 Loading deep linked profile: @\(username)")

                let response: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("username", value: username)
                    .execute()
                    .value

                if let profile = response.first {
                    await MainActor.run {
                        deepLinkedProfile = profile
                        print("✅ Deep linked profile loaded: @\(profile.username)")
                    }
                } else {
                    print("❌ Deep linked profile not found: @\(username)")
                    await MainActor.run {
                        deepLinkManager.clearPendingLink()
                    }
                }
            } catch {
                print("❌ Error loading deep linked profile: \(error)")
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

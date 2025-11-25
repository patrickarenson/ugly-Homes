//
//  NotificationsView.swift
//  Ugly Homes
//
//  In-app Notifications View
//

import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No notifications yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(notifications) { notification in
                            NotificationRowContent(
                                notification: notification,
                                triggeredByUserId: notification.triggeredByUserId
                            )
                            .onTapGesture {
                                markAsRead(notification)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notifications.isEmpty {
                        Button("Mark All Read") {
                            markAllAsRead()
                        }
                        .font(.subheadline)
                    }
                }
            }
            .onAppear {
                loadNotifications()
            }
            .refreshable {
                loadNotifications()
            }
        }
    }

    func loadNotifications() {
        isLoading = true

        Task {
            do {
                print("📥 Loading notifications...")

                // Get current user ID
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                // Load only THIS user's notifications
                let response: [AppNotification] = try await SupabaseManager.shared.client
                    .from("notifications")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) notifications for user \(userId)")
                notifications = response
                isLoading = false
            } catch {
                print("❌ Error loading notifications: \(error)")
                isLoading = false
            }
        }
    }

    func markAsRead(_ notification: AppNotification) {
        guard !notification.isRead else { return }

        Task {
            do {
                print("🔄 Marking notification \(notification.id) as read")

                try await SupabaseManager.shared.client
                    .from("notifications")
                    .update(["is_read": true])
                    .eq("id", value: notification.id.uuidString)
                    .execute()

                print("✅ Database updated for notification \(notification.id)")

                // Update local state
                await MainActor.run {
                    if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                        notifications[index] = AppNotification(
                            id: notification.id,
                            userId: notification.userId,
                            triggeredByUserId: notification.triggeredByUserId,
                            type: notification.type,
                            title: notification.title,
                            message: notification.message,
                            homeId: notification.homeId,
                            isRead: true,
                            createdAt: notification.createdAt
                        )
                    }

                    // Trigger badge refresh
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshNotifications"), object: nil)
                }

                print("✅ Local state updated for notification \(notification.id)")
            } catch {
                print("❌ Error marking notification as read: \(error)")
            }
        }
    }

    func markAllAsRead() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                print("🔄 Marking all notifications as read for user: \(userId)")

                try await SupabaseManager.shared.client
                    .from("notifications")
                    .update(["is_read": true])
                    .eq("user_id", value: userId.uuidString)
                    .eq("is_read", value: false)
                    .execute()

                print("✅ Database updated - all notifications marked as read")

                // Update local state immediately
                await MainActor.run {
                    for index in notifications.indices {
                        notifications[index] = AppNotification(
                            id: notifications[index].id,
                            userId: notifications[index].userId,
                            triggeredByUserId: notifications[index].triggeredByUserId,
                            type: notifications[index].type,
                            title: notifications[index].title,
                            message: notifications[index].message,
                            homeId: notifications[index].homeId,
                            isRead: true,
                            createdAt: notifications[index].createdAt
                        )
                    }
                }

                print("✅ Local state updated")

                // Trigger badge refresh
                await MainActor.run {
                    Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshNotifications"), object: nil)
                }

                print("✅ Badge refresh notification sent")
            } catch {
                print("❌ Error marking all as read: \(error)")
            }
        }
    }
}

struct NotificationRowContent: View {
    let notification: AppNotification
    let triggeredByUserId: UUID?
    @State private var selectedProfile: UUID?
    @State private var selectedPost: Home?
    @State private var post: Home?
    @State private var currentUserId: UUID?

    var body: some View {
        HStack(spacing: 12) {
            // Icon based on notification type
            Circle()
                .fill(iconColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                    .foregroundColor(.primary)

                formattedMessage(notification.message, triggeredByUserId: triggeredByUserId)

                Text(timeAgo(from: notification.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer(minLength: 8)

            // Right-aligned: Post thumbnail + Unread indicator
            HStack(spacing: 8) {
                // Post thumbnail - clickable to navigate to post
                if let post = post, let imageUrl = post.imageUrls.first {
                    Button(action: {
                        selectedPost = post
                    }) {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.vertical, 8)
        .navigationDestination(item: $selectedProfile) { userId in
            ProfileView(viewingUserId: userId)
        }
        .navigationDestination(item: $selectedPost) { post in
            PostDetailView(home: post, showSoldOptions: false, preloadedUserId: currentUserId)
        }
        .onAppear {
            loadPost()
            loadCurrentUserId()
        }
    }

    func loadPost() {
        guard let homeId = notification.homeId else { return }

        Task {
            do {
                // Load full home object with profile data
                let response: [Home] = try await SupabaseManager.shared.client
                    .from("homes")
                    .select("*, profile:user_id(*)")
                    .eq("id", value: homeId.uuidString)
                    .execute()
                    .value

                await MainActor.run {
                    post = response.first
                }
            } catch {
                print("❌ Error loading post: \(error)")
            }
        }
    }

    func loadCurrentUserId() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id
                await MainActor.run {
                    currentUserId = userId
                }
            } catch {
                print("❌ Error loading current user ID: \(error)")
            }
        }
    }

    var iconName: String {
        switch notification.type {
        case "like":
            return "heart.fill"
        case "comment":
            return "bubble.left.fill"
        case "follow":
            return "person.fill.badge.plus"
        case "open_house_cancelled":
            return "calendar.badge.exclamationmark"
        default:
            return "bell.fill"
        }
    }

    var iconColor: Color {
        switch notification.type {
        case "like":
            return .pink
        case "comment":
            return .blue
        case "follow":
            return .purple
        case "open_house_cancelled":
            return .red
        default:
            return .orange
        }
    }

    func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)

        if let week = components.weekOfYear, week > 0 {
            return "\(week)w ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "just now"
        }
    }

    func formattedMessage(_ message: String, triggeredByUserId: UUID?) -> some View {
        let cleanMessage = message.replacingOccurrences(of: ">", with: "").replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        let parts = cleanMessage.components(separatedBy: " ")
        let username = parts.first ?? ""
        let rest = parts.dropFirst().joined(separator: " ")

        return HStack(spacing: 0) {
            if let userId = triggeredByUserId {
                Button(action: {
                    selectedProfile = userId
                }) {
                    Text(username)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            } else {
                Text(username)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }

            Text(" \(rest)")
                .foregroundColor(.secondary)
        }
        .font(.system(size: 14))
        .lineLimit(2)
    }
}

#Preview {
    NotificationsView()
}

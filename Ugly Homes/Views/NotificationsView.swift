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
                            NotificationRow(notification: notification, onTap: {
                                markAsRead(notification)
                            })
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

                let response: [AppNotification] = try await SupabaseManager.shared.client
                    .from("notifications")
                    .select()
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                    .value

                print("✅ Loaded \(response.count) notifications")
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
                try await SupabaseManager.shared.client
                    .from("notifications")
                    .update(["is_read": true])
                    .eq("id", value: notification.id.uuidString)
                    .execute()

                // Update local state
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[index] = AppNotification(
                        id: notification.id,
                        userId: notification.userId,
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
            } catch {
                print("❌ Error marking notification as read: \(error)")
            }
        }
    }

    func markAllAsRead() {
        Task {
            do {
                let userId = try await SupabaseManager.shared.client.auth.session.user.id

                try await SupabaseManager.shared.client
                    .from("notifications")
                    .update(["is_read": true])
                    .eq("user_id", value: userId.uuidString)
                    .eq("is_read", value: false)
                    .execute()

                loadNotifications()

                // Trigger badge refresh
                Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshNotifications"), object: nil)
            } catch {
                print("❌ Error marking all as read: \(error)")
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(timeAgo(from: notification.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    var iconName: String {
        switch notification.type {
        case "like":
            return "heart.fill"
        case "comment":
            return "bubble.left.fill"
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
}

#Preview {
    NotificationsView()
}

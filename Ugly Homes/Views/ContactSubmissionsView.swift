//
//  ContactSubmissionsView.swift
//  Ugly Homes
//
//  Admin View - View all contact form submissions with summaries
//

import SwiftUI

struct ContactSubmissionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var submissions: [ContactSubmission] = []
    @State private var isLoading = true
    @State private var selectedFilter: FilterOption = .all
    @State private var selectedStatus: StatusFilter = .all

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case advertise = "Advertise"
        case feedback = "Feedback"
        case other = "Other"
    }

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case read = "Read"
        case resolved = "Resolved"
    }

    struct ContactSubmission: Codable, Identifiable {
        let id: UUID
        let userId: UUID
        let category: String
        let message: String?
        let userEmail: String
        let userName: String
        var status: String
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case category
            case message
            case userEmail = "user_email"
            case userName = "user_name"
            case status
            case createdAt = "created_at"
        }
    }

    var filteredSubmissions: [ContactSubmission] {
        submissions.filter { submission in
            let categoryMatch = selectedFilter == .all || submission.category == selectedFilter.rawValue.lowercased()
            let statusMatch = selectedStatus == .all || submission.status == selectedStatus.rawValue.lowercased()
            return categoryMatch && statusMatch
        }
    }

    var totalSubmissions: Int { submissions.count }
    var advertiseCount: Int { submissions.filter { $0.category == "advertise" }.count }
    var feedbackCount: Int { submissions.filter { $0.category == "feedback" }.count }
    var otherCount: Int { submissions.filter { $0.category == "other" }.count }
    var unreadCount: Int { submissions.filter { $0.status == "unread" }.count }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading submissions...")
                        .padding()
                } else {
                    // Summary cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            SummaryCard(title: "Total", count: totalSubmissions, icon: "envelope.fill", color: .orange)
                            SummaryCard(title: "Unread", count: unreadCount, icon: "envelope.badge.fill", color: .red)
                            SummaryCard(title: "Advertise", count: advertiseCount, icon: "megaphone.fill", color: .blue)
                            SummaryCard(title: "Feedback", count: feedbackCount, icon: "bubble.left.and.bubble.right.fill", color: .green)
                            SummaryCard(title: "Other", count: otherCount, icon: "questionmark.circle.fill", color: .gray)
                        }
                        .padding()
                    }

                    // Filters
                    VStack(spacing: 12) {
                        // Category filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(FilterOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        selectedFilter = option
                                    }) {
                                        Text(option.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(selectedFilter == option ? .semibold : .regular)
                                            .foregroundColor(selectedFilter == option ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedFilter == option ? Color.orange : Color.gray.opacity(0.2))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Status filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StatusFilter.allCases, id: \.self) { status in
                                    Button(action: {
                                        selectedStatus = status
                                    }) {
                                        Text(status.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(selectedStatus == status ? .semibold : .regular)
                                            .foregroundColor(selectedStatus == status ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedStatus == status ? Color.blue : Color.gray.opacity(0.2))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 8)

                    // Submissions list
                    if filteredSubmissions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No submissions")
                                .font(.title3)
                                .foregroundColor(.gray)

                            Text("No contact submissions match your filters")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredSubmissions) { submission in
                                SubmissionRow(submission: submission) {
                                    updateStatus(submissionId: submission.id, newStatus: $0)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Contact Submissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        loadSubmissions()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadSubmissions()
            }
        }
    }

    func loadSubmissions() {
        isLoading = true

        Task {
            do {
                let response: [ContactSubmission] = try await SupabaseManager.shared.client
                    .from("contact_submissions")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                await MainActor.run {
                    submissions = response
                    isLoading = false
                }

                print("✅ Loaded \(response.count) contact submissions")

            } catch {
                print("❌ Error loading submissions: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    func updateStatus(submissionId: UUID, newStatus: String) {
        Task {
            do {
                struct StatusUpdate: Codable {
                    let status: String
                }

                try await SupabaseManager.shared.client
                    .from("contact_submissions")
                    .update(StatusUpdate(status: newStatus))
                    .eq("id", value: submissionId.uuidString)
                    .execute()

                // Update local state
                await MainActor.run {
                    if let index = submissions.firstIndex(where: { $0.id == submissionId }) {
                        submissions[index].status = newStatus
                    }
                }

                print("✅ Updated submission status to: \(newStatus)")

            } catch {
                print("❌ Error updating status: \(error)")
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text("\(count)")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 100)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SubmissionRow: View {
    let submission: ContactSubmissionsView.ContactSubmission
    let onStatusUpdate: (String) -> Void

    @State private var showDetail = false

    var categoryIcon: String {
        switch submission.category {
        case "advertise": return "megaphone.fill"
        case "feedback": return "bubble.left.and.bubble.right.fill"
        default: return "envelope.fill"
        }
    }

    var categoryColor: Color {
        switch submission.category {
        case "advertise": return .blue
        case "feedback": return .green
        default: return .gray
        }
    }

    var statusColor: Color {
        switch submission.status {
        case "unread": return .red
        case "read": return .orange
        case "resolved": return .green
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                // Category icon
                Image(systemName: categoryIcon)
                    .font(.title3)
                    .foregroundColor(categoryColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(submission.userName)
                        .font(.headline)

                    Text(submission.userEmail)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Status badge
                Text(submission.status.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(6)
            }

            // Message preview
            if let message = submission.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            } else {
                Text("(No message)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .italic()
            }

            // Footer row
            HStack {
                Text(timeAgoString(from: submission.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                // Status buttons
                Menu {
                    Button("Mark as Unread") {
                        onStatusUpdate("unread")
                    }
                    Button("Mark as Read") {
                        onStatusUpdate("read")
                    }
                    Button("Mark as Resolved") {
                        onStatusUpdate("resolved")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Update")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }

    func timeAgoString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return day == 1 ? "1 day ago" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 min ago" : "\(minute) mins ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    ContactSubmissionsView()
}

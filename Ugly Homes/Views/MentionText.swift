//
//  MentionText.swift
//  Ugly Homes
//
//  Component for displaying text with clickable @mentions
//

import SwiftUI

struct MentionText: View {
    let text: String
    let font: Font
    let baseColor: Color
    let mentionColor: Color
    @State private var mentionedUsers: [String: UUID] = [:]
    @State private var showProfile: ProfileDestination?

    struct ProfileDestination: Identifiable {
        let id: UUID
        var id_value: UUID { id }
    }

    init(text: String, font: Font = .body, baseColor: Color = .primary, mentionColor: Color = .blue) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
        self.mentionColor = mentionColor
    }

    var body: some View {
        textWithMentions
            .font(font)
            .sheet(item: $showProfile) { destination in
                ProfileView(viewingUserId: destination.id)
            }
            .onAppear {
                loadMentionedUsers()
            }
    }

    private var textWithMentions: some View {
        let pattern = "@([a-zA-Z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []

        var segments: [(text: String, isMention: Bool, username: String?)] = []
        var lastIndex = 0

        for match in matches {
            // Add text before mention
            if match.range.location > lastIndex {
                let beforeText = nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
                segments.append((beforeText, false, nil))
            }

            // Add mention
            let fullMatch = nsString.substring(with: match.range)
            let usernameRange = match.range(at: 1)
            let username = nsString.substring(with: usernameRange)
            segments.append((fullMatch, true, username))

            lastIndex = match.range.location + match.range.length
        }

        // Add remaining text
        if lastIndex < nsString.length {
            let remainingText = nsString.substring(from: lastIndex)
            segments.append((remainingText, false, nil))
        }

        return segments.reduce(Text("")) { result, segment in
            if segment.isMention, let username = segment.username {
                return result + Text(segment.text)
                    .foregroundColor(mentionColor)
                    .fontWeight(.semibold)
                    .onTapGesture {
                        handleMentionTap(username: username)
                    }
            } else {
                return result + Text(segment.text)
                    .foregroundColor(baseColor)
            }
        }
    }

    private func handleMentionTap(username: String) {
        // Check if we already have this user's ID cached
        if let userId = mentionedUsers[username] {
            showProfile = ProfileDestination(id: userId)
        } else {
            // Look up user by username
            Task {
                do {
                    let profiles: [Profile] = try await SupabaseManager.shared.client
                        .from("profiles")
                        .select()
                        .eq("username", value: username)
                        .execute()
                        .value

                    if let profile = profiles.first {
                        await MainActor.run {
                            mentionedUsers[username] = profile.id
                            showProfile = ProfileDestination(id: profile.id)
                        }
                    }
                } catch {
                    print("❌ Error looking up mentioned user: \(error)")
                }
            }
        }
    }

    private func loadMentionedUsers() {
        // Extract all @mentions from text
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        let usernames = matches.compactMap { match -> String? in
            let usernameRange = match.range(at: 1)
            return nsString.substring(with: usernameRange)
        }

        // Batch load all mentioned users
        guard !usernames.isEmpty else { return }

        Task {
            do {
                let profiles: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .in("username", values: usernames)
                    .execute()
                    .value

                await MainActor.run {
                    for profile in profiles {
                        mentionedUsers[profile.username] = profile.id
                    }
                }

                print("✅ Loaded \(profiles.count) mentioned users")
            } catch {
                print("❌ Error loading mentioned users: \(error)")
            }
        }
    }
}

// Alternative view for comments that need NavigationLink instead of sheet
struct MentionTextWithNavigation: View {
    let text: String
    let font: Font
    let baseColor: Color
    let mentionColor: Color
    @State private var mentionedUsers: [String: UUID] = [:]

    init(text: String, font: Font = .body, baseColor: Color = .primary, mentionColor: Color = .blue) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
        self.mentionColor = mentionColor
    }

    var body: some View {
        textWithMentions
            .font(font)
            .onAppear {
                loadMentionedUsers()
            }
    }

    private var textWithMentions: some View {
        let pattern = "@([a-zA-Z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []

        var segments: [(text: String, isMention: Bool, username: String?)] = []
        var lastIndex = 0

        for match in matches {
            // Add text before mention
            if match.range.location > lastIndex {
                let beforeText = nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
                segments.append((beforeText, false, nil))
            }

            // Add mention
            let fullMatch = nsString.substring(with: match.range)
            let usernameRange = match.range(at: 1)
            let username = nsString.substring(with: usernameRange)
            segments.append((fullMatch, true, username))

            lastIndex = match.range.location + match.range.length
        }

        // Add remaining text
        if lastIndex < nsString.length {
            let remainingText = nsString.substring(from: lastIndex)
            segments.append((remainingText, false, nil))
        }

        return HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if segment.isMention, let username = segment.username, let userId = mentionedUsers[username] {
                    NavigationLink(destination: ProfileView(viewingUserId: userId)) {
                        Text(segment.text)
                            .foregroundColor(mentionColor)
                            .fontWeight(.semibold)
                    }
                } else {
                    Text(segment.text)
                        .foregroundColor(baseColor)
                }
            }
        }
    }

    private func loadMentionedUsers() {
        // Extract all @mentions from text
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        let usernames = matches.compactMap { match -> String? in
            let usernameRange = match.range(at: 1)
            return nsString.substring(with: usernameRange)
        }

        // Batch load all mentioned users
        guard !usernames.isEmpty else { return }

        Task {
            do {
                let profiles: [Profile] = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .in("username", values: usernames)
                    .execute()
                    .value

                await MainActor.run {
                    for profile in profiles {
                        mentionedUsers[profile.username] = profile.id
                    }
                }

                print("✅ Loaded \(profiles.count) mentioned users")
            } catch {
                print("❌ Error loading mentioned users: \(error)")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MentionText(
            text: "Check out this house! @john and @sarah would love it. What do you think @mike?",
            font: .body
        )

        MentionText(
            text: "Amazing property listed by @realestate_pro! Contact @agent123 for details.",
            font: .subheadline,
            baseColor: .gray
        )
    }
    .padding()
}

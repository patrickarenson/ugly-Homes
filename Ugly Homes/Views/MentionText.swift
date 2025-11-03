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

    init(text: String, font: Font = .body, baseColor: Color = .primary, mentionColor: Color = .blue) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
        self.mentionColor = mentionColor
    }

    var body: some View {
        textWithMentions
            .font(font)
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

        // Build Text with styled mentions
        return segments.reduce(Text("")) { result, segment in
            if segment.isMention {
                return result + Text(segment.text)
                    .foregroundColor(mentionColor)
                    .fontWeight(.semibold)
            } else {
                return result + Text(segment.text)
                    .foregroundColor(baseColor)
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

//
//  TagView.swift
//  Ugly Homes
//
//  Displays hashtags for property listings
//

import SwiftUI

struct TagView: View {
    let tag: String
    let onTap: (() -> Void)?

    init(tag: String, onTap: (() -> Void)? = nil) {
        self.tag = tag
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            Text(tag)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Display a horizontal list of tags
struct TagListView: View {
    let tags: [String]
    let maxTags: Int
    let onTagTap: ((String) -> Void)?

    init(tags: [String], maxTags: Int = 3, onTagTap: ((String) -> Void)? = nil) {
        self.tags = tags
        self.maxTags = maxTags
        self.onTagTap = onTagTap
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(tags.prefix(maxTags)), id: \.self) { tag in
                TagView(tag: tag) {
                    onTagTap?(tag)
                }
            }
        }
    }
}

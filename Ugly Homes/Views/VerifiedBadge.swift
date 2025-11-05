//
//  VerifiedBadge.swift
//  Ugly Homes
//
//  Verified Badge Component
//

import SwiftUI

struct VerifiedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .foregroundColor(.blue)
            .font(.system(size: 14))
    }
}

#Preview {
    VerifiedBadge()
}

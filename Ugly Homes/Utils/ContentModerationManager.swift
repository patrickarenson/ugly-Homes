//
//  ContentModerationManager.swift
//  Ugly Homes
//
//  Proactive Content Moderation - App Store Compliance
//

import Foundation
import UIKit

enum ModerationResult {
    case approved
    case blocked(reason: String)
    case flaggedForReview(reason: String, filteredText: String)
}

class ContentModerationManager {
    static let shared = ContentModerationManager()

    private init() {}

    // MARK: - Severe Profanity & Slurs (Auto-block)
    private let blockedWords: [String] = [
        // Extreme profanity only
        "fuck", "fucking", "fucker", "fucked", "motherfucker",
        "cunt", "pussy",

        // Racial slurs (partial list - sensitive)
        "nigger", "nigga", "chink", "spic", "wetback", "beaner", "kike",
        "towelhead", "raghead", "gook", "jap", "paki",

        // Homophobic slurs
        "fag", "faggot", "dyke",

        // Sexual/explicit content
        "porn", "pornography", "xxx", "sex tape", "nudes",
        "onlyfans", "escort", "prostitute", "hooker", "brothel",

        // Violence & threats
        "kill you", "murder you", "rape", "terrorist", "bomb threat",
        "shoot you", "attack you", "death threat", "going to kill",

        // Extreme discrimination
        "no blacks", "no mexicans", "no muslims", "no jews", "no asians",
        "whites only", "no arabs", "no hispanics", "no gays"
    ]

    // MARK: - Suspicious/Scam Phrases (Flag for review)
    private let flaggedPhrases: [String] = [
        // Scam/spam
        "click here", "free money", "earn $$$", "make money fast",
        "wire transfer", "western union", "bitcoin", "crypto investment",
        "send money", "cash only", "no questions asked",

        // Fair housing violations
        "adults only", "no children", "no kids", "perfect for christians",
        "perfect for families", "mature tenants", "no section 8",
        "no disabled", "no handicapped",

        // Suspicious patterns
        "100% guarantee", "limited time", "act now", "urgent",
        "nigerian prince", "inheritance",

        // External redirects
        "telegram", "whatsapp me", "text me at", "call me at",
        "email me at", "dm me", "snapchat", "kik"
    ]

    // MARK: - Public Methods

    /// Moderate text content (title, description, comments)
    func moderateText(_ text: String) -> ModerationResult {
        let lowercased = text.lowercased()

        // 1. Check for auto-block words
        for word in blockedWords {
            if lowercased.contains(word) {
                print("🚫 Content blocked: Contains '\(word)'")
                return .blocked(reason: "Content contains prohibited language")
            }
        }

        // 2. Check for suspicious URLs
        if containsSuspiciousURL(lowercased) {
            print("⚠️ Content flagged: Suspicious URL detected")
            return .flaggedForReview(reason: "Contains external links", filteredText: text)
        }

        // 3. Check for scam/spam phrases
        for phrase in flaggedPhrases {
            if lowercased.contains(phrase) {
                print("⚠️ Content flagged: Contains '\(phrase)'")
                return .flaggedForReview(reason: "Potential spam or fair housing violation", filteredText: text)
            }
        }

        // 4. Check for excessive caps (spam indicator)
        if isExcessiveCaps(text) {
            print("⚠️ Content flagged: Excessive capitalization")
            return .flaggedForReview(reason: "Excessive capitalization (spam indicator)", filteredText: text)
        }

        // All clear
        return .approved
    }

    /// Validate image before upload
    func validateImage(_ imageData: Data, filename: String?) -> (isValid: Bool, error: String?) {
        // 1. Check file size (max 10MB)
        let maxSize = 10 * 1024 * 1024 // 10MB
        if imageData.count > maxSize {
            return (false, "Image size exceeds 10MB limit")
        }

        // 2. Check minimum size (1KB to prevent tiny tracking pixels)
        let minSize = 1024 // 1KB
        if imageData.count < minSize {
            return (false, "Image file is too small")
        }

        // 3. Validate file type
        if let filename = filename {
            let lowercasedFilename = filename.lowercased()
            let allowedExtensions = ["jpg", "jpeg", "png", "heic"]
            let hasValidExtension = allowedExtensions.contains { ext in
                lowercasedFilename.hasSuffix(".\(ext)")
            }

            if !hasValidExtension {
                return (false, "Only JPEG, PNG, and HEIC images are allowed")
            }
        }

        // 4. Check image dimensions using UIImage
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else {
            return (false, "Invalid image file")
        }

        let minDimension: CGFloat = 100
        let maxDimension: CGFloat = 4096

        if image.size.width < minDimension || image.size.height < minDimension {
            return (false, "Image dimensions too small (minimum 100x100)")
        }

        if image.size.width > maxDimension || image.size.height > maxDimension {
            return (false, "Image dimensions too large (maximum 4096x4096)")
        }
        #endif

        return (true, nil)
    }

    // MARK: - Helper Methods

    private func isExcessiveCaps(_ text: String) -> Bool {
        // More than 60% uppercase letters in text longer than 10 chars
        guard text.count > 10 else { return false }

        let uppercaseCount = text.filter { $0.isUppercase }.count
        let letterCount = text.filter { $0.isLetter }.count

        guard letterCount > 0 else { return false }

        let capsPercentage = Double(uppercaseCount) / Double(letterCount)
        return capsPercentage > 0.6
    }

    private func containsSuspiciousURL(_ text: String) -> Bool {
        // Detect common URL patterns
        let urlPatterns = [
            "http://", "https://", "www.", ".com", ".org", ".net",
            ".ru", ".tk", ".ml", ".ga", // Suspicious TLDs
            "bit.ly", "tinyurl", "goo.gl" // URL shorteners
        ]

        for pattern in urlPatterns {
            if text.contains(pattern) {
                // Allow housers.app URLs
                if text.contains("housers.app") {
                    continue
                }
                return true
            }
        }

        return false
    }

    /// Moderate multiple text fields (for post creation)
    func moderatePost(title: String, description: String?) -> ModerationResult {
        // Check title
        let titleResult = moderateText(title)
        if case .blocked = titleResult {
            return titleResult
        }

        // Check description
        if let desc = description, !desc.isEmpty {
            let descResult = moderateText(desc)
            if case .blocked = descResult {
                return descResult
            }

            // If description is flagged, return that
            if case .flaggedForReview = descResult {
                return descResult
            }
        }

        // If title is flagged, return that
        if case .flaggedForReview = titleResult {
            return titleResult
        }

        return .approved
    }
}

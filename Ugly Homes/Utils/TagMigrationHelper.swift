//
//  TagMigrationHelper.swift
//  Ugly Homes
//
//  Utility to retroactively update tags for all existing properties
//

import Foundation

struct TagMigrationHelper {

    /// Regenerate tags for all existing properties in the database
    static func updateAllPropertyTags() async throws {
        print("🔄 Starting tag migration for all properties...")

        // Fetch all homes from database
        let homes: [Home] = try await SupabaseManager.shared.client
            .from("homes")
            .select()
            .execute()
            .value

        print("📊 Found \(homes.count) properties to update")

        var successCount = 0
        var failCount = 0

        // Update each home with regenerated tags
        for home in homes {
            do {
                // Regenerate tags using current TagGenerator logic
                let newTags = TagGenerator.generateTags(
                    city: home.city,
                    price: home.price,
                    bedrooms: home.bedrooms,
                    title: home.title,
                    description: home.description,
                    listingType: home.listingType
                )

                // Create update structure
                struct HomeTagsUpdate: Encodable {
                    let tags: [String]
                    let updated_at: Date
                }

                let update = HomeTagsUpdate(tags: newTags, updated_at: Date())

                // Update the home in database
                try await SupabaseManager.shared.client
                    .from("homes")
                    .update(update)
                    .eq("id", value: home.id.uuidString)
                    .execute()

                successCount += 1
                print("✅ Updated tags for property: \(home.id) - Tags: \(newTags)")

            } catch {
                failCount += 1
                print("❌ Failed to update property \(home.id): \(error)")
            }
        }

        print("🎉 Tag migration complete!")
        print("✅ Successfully updated: \(successCount)")
        print("❌ Failed: \(failCount)")

        // Post notification to refresh the feed
        await MainActor.run {
            Foundation.NotificationCenter.default.post(name: Foundation.Notification.Name("RefreshFeed"), object: nil)
        }
    }
}

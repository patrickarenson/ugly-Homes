//
//  OpenHouseTagMigration.swift
//  Ugly Homes
//
//  Utility to add #OpenHouse tag to existing posts with open houses
//

import Foundation

struct OpenHouseTagMigration {

    /// Add #OpenHouse tag to all posts that have open houses but don't have the tag yet
    static func addOpenHouseTagsToExistingPosts() async throws {
        print("🔄 Starting Open House tag migration...")

        // Fetch all posts with open houses
        let homes: [Home] = try await SupabaseManager.shared.client
            .from("homes")
            .select()
            .eq("open_house_paid", value: true)
            .execute()
            .value

        print("📊 Found \(homes.count) posts with open houses")

        var successCount = 0
        var failCount = 0

        for home in homes {
            do {
                var updatedTags = home.tags ?? []

                // Only add if not already present
                if !updatedTags.contains("#OpenHouse") {
                    updatedTags.append("#OpenHouse")

                    struct TagsUpdate: Encodable {
                        let tags: [String]
                    }

                    try await SupabaseManager.shared.client
                        .from("homes")
                        .update(TagsUpdate(tags: updatedTags))
                        .eq("id", value: home.id.uuidString)
                        .execute()

                    print("✅ Added #OpenHouse tag to: \(home.title)")
                    successCount += 1
                } else {
                    print("⏭️ Skipped (already has tag): \(home.title)")
                }
            } catch {
                print("❌ Failed for \(home.title): \(error)")
                failCount += 1
            }
        }

        print("✅ Migration complete: \(successCount) updated, \(failCount) failed")
    }
}

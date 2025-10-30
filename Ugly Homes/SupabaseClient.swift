//
//  SupabaseClient.swift
//  Ugly Homes
//
//  Created by Supabase Configuration
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://pgezrygzubjieqfzyccy.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MzE5NjcsImV4cCI6MjA3NzQwNzk2N30.-AK_lNlPfjdPCyXP2KySnFFZ3D_u5UbczXmcOFD6AA8"
        )
    }
}

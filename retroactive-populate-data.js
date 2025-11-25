#!/usr/bin/env node

/**
 * Retroactive Data Population Script
 *
 * Fixes missing descriptions and square footage for automated @houser posts
 * Run this to backfill data for posts that were imported before the API fix
 */

const { createClient } = require('@supabase/supabase-js');

// CONFIGURATION
const SUPABASE_URL = 'https://pgezrygzubjieqfzyccy.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTgzMTk2NywiZXhwIjoyMDc3NDA3OTY3fQ.seH1M4i7XjDOCCKePsSXdDmnQ4SgWBAsiODJ7Oiz06g';
const SCRAPING_API = 'https://api.housers.us/api/scrape-listing';
const HOUSER_USERNAME = 'houser';

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

/**
 * Get the Houser user ID from Supabase
 */
async function getHouserUserId() {
  console.log('📝 Looking up Houser user ID...');

  const { data, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('username', HOUSER_USERNAME)
    .single();

  if (error) {
    throw new Error(`Could not find user "${HOUSER_USERNAME}": ${error.message}`);
  }

  console.log(`✅ Found Houser ID: ${data.id}`);
  return data.id;
}

/**
 * Get recent @houser posts with missing data (last 3 days)
 */
async function getTodaysPostsWithMissingData(houserUserId) {
  console.log('🔍 Finding recent posts with missing description or square footage...');

  // Get start of 3 days ago (midnight)
  const threeDaysAgo = new Date();
  threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
  threeDaysAgo.setHours(0, 0, 0, 0);

  const { data, error } = await supabase
    .from('homes')
    .select('id, source_url, description, living_area_sqft, address')
    .eq('user_id', houserUserId)
    .gte('created_at', threeDaysAgo.toISOString())
    .or('description.is.null,living_area_sqft.is.null');

  if (error) {
    throw new Error(`Failed to query posts: ${error.message}`);
  }

  console.log(`✅ Found ${data.length} posts needing data`);
  return data;
}

/**
 * Scrape property details from source URL
 */
async function scrapeProperty(sourceUrl) {
  console.log(`🔍 Re-scraping: ${sourceUrl}`);

  const response = await fetch(SCRAPING_API, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ url: sourceUrl })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Scraping failed: ${error}`);
  }

  return await response.json();
}

/**
 * Update a post with missing data
 */
async function updatePost(postId, propertyData) {
  const updates = {};

  // Add description if missing
  if (propertyData.description) {
    updates.description = propertyData.description;
  }

  // Add square footage if missing
  if (propertyData.livingAreaSqft) {
    updates.living_area_sqft = propertyData.livingAreaSqft;
  }

  if (Object.keys(updates).length === 0) {
    console.log(`⚠️ No data to update for post ${postId}`);
    return false;
  }

  console.log(`📝 Updating post ${postId} with:`, Object.keys(updates).join(', '));

  const { error } = await supabase
    .from('homes')
    .update(updates)
    .eq('id', postId);

  if (error) {
    throw new Error(`Failed to update post: ${error.message}`);
  }

  console.log(`✅ Updated post ${postId}`);
  return true;
}

/**
 * Main execution function
 */
async function main() {
  console.log('🔧 Starting retroactive data population...\n');

  try {
    // 1. Get Houser user ID
    const houserUserId = await getHouserUserId();

    // 2. Find today's posts with missing data
    const postsNeedingData = await getTodaysPostsWithMissingData(houserUserId);

    if (postsNeedingData.length === 0) {
      console.log('\n✅ No posts need updating!');
      return;
    }

    console.log(`\n📋 Processing ${postsNeedingData.length} posts...\n`);

    // 3. Process each post
    let updated = 0;
    let failed = 0;
    let noData = 0;

    for (const post of postsNeedingData) {
      try {
        console.log(`\n--- Processing: ${post.address || post.id} ---`);
        console.log(`Missing: ${!post.description ? 'description' : ''} ${!post.living_area_sqft ? 'square footage' : ''}`);

        if (!post.source_url) {
          console.log(`⚠️ No source URL for post ${post.id}, skipping`);
          noData++;
          continue;
        }

        // Re-scrape property data
        const propertyData = await scrapeProperty(post.source_url);

        // Update the post
        const wasUpdated = await updatePost(post.id, propertyData);

        if (wasUpdated) {
          updated++;
        } else {
          noData++;
        }

        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000));

      } catch (error) {
        console.error(`❌ Failed to process post ${post.id}: ${error.message}`);
        failed++;
      }
    }

    // 4. Summary
    console.log('\n📊 Summary:');
    console.log(`✅ Updated: ${updated}`);
    console.log(`⚠️ No new data available: ${noData}`);
    console.log(`❌ Failed: ${failed}`);

  } catch (error) {
    console.error(`\n💥 Fatal error: ${error.message}`);
    process.exit(1);
  }
}

// Run the script
main();

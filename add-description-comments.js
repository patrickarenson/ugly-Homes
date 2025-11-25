#!/usr/bin/env node

/**
 * Add Description Comments to @houser Posts
 *
 * Creates the first comment with the full description for automated posts
 * that are missing this comment
 */

const { createClient } = require('@supabase/supabase-js');

// CONFIGURATION
const SUPABASE_URL = 'https://pgezrygzubjieqfzyccy.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTgzMTk2NywiZXhwIjoyMDc3NDA3OTY3fQ.seH1M4i7XjDOCCKePsSXdDmnQ4SgWBAsiODJ7Oiz06g';
const HOUSER_USERNAME = 'houser';

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

/**
 * Get the Houser user ID
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
 * Get recent @houser posts with descriptions but no comments
 */
async function getPostsNeedingComments(houserUserId) {
  console.log('🔍 Finding posts with descriptions but no comments...');

  // Get posts from last 3 days
  const threeDaysAgo = new Date();
  threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
  threeDaysAgo.setHours(0, 0, 0, 0);

  // Get all posts with descriptions
  const { data: posts, error: postsError } = await supabase
    .from('homes')
    .select('id, description, created_at')
    .eq('user_id', houserUserId)
    .gte('created_at', threeDaysAgo.toISOString())
    .not('description', 'is', null)
    .order('created_at', { ascending: false });

  if (postsError) {
    throw new Error(`Failed to query posts: ${postsError.message}`);
  }

  // Filter to only posts that don't have comments yet
  const postsNeedingComments = [];

  for (const post of posts) {
    const { data: comments, error: commentsError } = await supabase
      .from('comments')
      .select('id')
      .eq('home_id', post.id)
      .eq('user_id', houserUserId)
      .limit(1);

    if (commentsError) {
      console.error(`⚠️ Error checking comments for post ${post.id}: ${commentsError.message}`);
      continue;
    }

    // If no comments exist, add to list
    if (!comments || comments.length === 0) {
      postsNeedingComments.push(post);
    }
  }

  console.log(`✅ Found ${postsNeedingComments.length} posts needing description comments`);
  return postsNeedingComments;
}

/**
 * Create a comment with the description
 */
async function createDescriptionComment(houserUserId, homeId, description) {
  console.log(`💬 Creating description comment for post ${homeId}`);

  const { error } = await supabase
    .from('comments')
    .insert({
      home_id: homeId,
      user_id: houserUserId,
      comment_text: description,
      created_at: new Date().toISOString()
    });

  if (error) {
    throw new Error(`Failed to create comment: ${error.message}`);
  }

  // Also increment comments_count on the home
  const { error: updateError } = await supabase
    .from('homes')
    .update({ comments_count: 1 })
    .eq('id', homeId);

  if (updateError) {
    console.error(`⚠️ Failed to update comments_count: ${updateError.message}`);
  }

  console.log(`✅ Created description comment for post ${homeId}`);
}

/**
 * Main execution function
 */
async function main() {
  console.log('💬 Starting description comment creation...\n');

  try {
    // 1. Get Houser user ID
    const houserUserId = await getHouserUserId();

    // 2. Find posts needing comments
    const postsNeedingComments = await getPostsNeedingComments(houserUserId);

    if (postsNeedingComments.length === 0) {
      console.log('\n✅ All posts already have description comments!');
      return;
    }

    console.log(`\n📋 Processing ${postsNeedingComments.length} posts...\n`);

    // 3. Create comments
    let created = 0;
    let failed = 0;

    for (const post of postsNeedingComments) {
      try {
        await createDescriptionComment(houserUserId, post.id, post.description);
        created++;

        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 500));

      } catch (error) {
        console.error(`❌ Failed to create comment for post ${post.id}: ${error.message}`);
        failed++;
      }
    }

    // 4. Summary
    console.log('\n📊 Summary:');
    console.log(`✅ Created: ${created}`);
    console.log(`❌ Failed: ${failed}`);

  } catch (error) {
    console.error(`\n💥 Fatal error: ${error.message}`);
    process.exit(1);
  }
}

// Run the script
main();

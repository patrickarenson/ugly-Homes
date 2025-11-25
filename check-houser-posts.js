#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://pgezrygzubjieqfzyccy.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTgzMTk2NywiZXhwIjoyMDc3NDA3OTY3fQ.seH1M4i7XjDOCCKePsSXdDmnQ4SgWBAsiODJ7Oiz06g';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function main() {
  // Get houser user ID
  const { data: profile } = await supabase
    .from('profiles')
    .select('id')
    .eq('username', 'houser')
    .single();

  const houserUserId = profile.id;
  console.log('Houser User ID:', houserUserId);

  // Get last 10 houser posts
  const { data: posts } = await supabase
    .from('homes')
    .select('id, created_at, address, description, living_area_sqft')
    .eq('user_id', houserUserId)
    .order('created_at', { ascending: false })
    .limit(10);

  console.log('\nLast 10 @houser posts:\n');
  posts.forEach((post, i) => {
    console.log(`${i + 1}. ${post.address || 'No address'}`);
    console.log(`   Created: ${post.created_at}`);
    console.log(`   Description: ${post.description ? 'YES (' + post.description.substring(0, 50) + '...)' : 'MISSING ❌'}`);
    console.log(`   Square Footage: ${post.living_area_sqft || 'MISSING ❌'}`);
    console.log('');
  });
}

main();

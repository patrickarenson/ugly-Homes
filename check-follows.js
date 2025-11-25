require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://pgezrygzubjieqfzyccy.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkFollows() {
  // Get houser user ID
  const { data: houser } = await supabase
    .from('profiles')
    .select('id, username')
    .eq('username', 'houser')
    .single();

  // Get patrick user ID
  const { data: patrick } = await supabase
    .from('profiles')
    .select('id, username')
    .eq('username', 'patrick')
    .single();

  if (!houser || !patrick) {
    console.log('❌ Users not found');
    return;
  }

  console.log('Houser ID:', houser.id);
  console.log('Patrick ID:', patrick.id);

  // Check if patrick follows houser
  const { data: follows, error } = await supabase
    .from('follows')
    .select('*')
    .eq('following_id', houser.id)
    .order('created_at', { ascending: false })
    .limit(5);

  if (error) {
    console.log('Error:', error.message);
    return;
  }

  console.log('\nRecent follows for @houser:');
  follows.forEach(follow => {
    console.log(`- Follower ID: ${follow.follower_id}`);
    console.log(`  Created: ${follow.created_at}`);
  });

  console.log(`\nTotal followers: ${follows.length}`);
}

checkFollows();

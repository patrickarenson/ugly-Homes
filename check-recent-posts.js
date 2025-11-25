require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://pgezrygzubjieqfzyccy.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function checkRecentPosts() {
  const { data: houser } = await supabase
    .from('profiles')
    .select('id')
    .eq('username', 'houser')
    .single();

  if (!houser) {
    console.log('❌ Houser user not found');
    return;
  }

  const houserUserId = houser.id;

  // Get posts from the last 5 days, grouped by date
  const fiveDaysAgo = new Date();
  fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);

  const { data: posts } = await supabase
    .from('homes')
    .select('id, address, created_at')
    .eq('user_id', houserUserId)
    .gte('created_at', fiveDaysAgo.toISOString())
    .order('created_at', { ascending: false });

  console.log('\nPosts by date (last 5 days):');
  
  const postsByDate = {};
  posts.forEach(post => {
    const date = post.created_at.split('T')[0];
    if (!postsByDate[date]) {
      postsByDate[date] = [];
    }
    postsByDate[date].push(post);
  });

  Object.keys(postsByDate).sort().reverse().forEach(date => {
    console.log(`\n${date}: ${postsByDate[date].length} posts`);
    postsByDate[date].slice(0, 3).forEach(post => {
      console.log(`  - ${post.address}`);
    });
  });
}

checkRecentPosts();

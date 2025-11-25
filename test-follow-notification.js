require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://pgezrygzubjieqfzyccy.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function testFollowNotification() {
  const houserUserId = '23299d40-b668-416f-9bec-6298d50db5bc';
  const patrickUserId = '6ed1dbd2-81c7-4743-b52e-cf21bca70196';

  console.log('1. Unfollowing houser...');
  await supabase
    .from('follows')
    .delete()
    .eq('follower_id', patrickUserId)
    .eq('following_id', houserUserId);

  console.log('2. Following houser again...');
  const { error } = await supabase
    .from('follows')
    .insert({
      follower_id: patrickUserId,
      following_id: houserUserId
    });

  if (error) {
    console.log('❌ Error:', error.message);
    return;
  }

  console.log('3. Waiting 1 second for trigger...');
  await new Promise(resolve => setTimeout(resolve, 1000));

  console.log('4. Checking notifications...');
  const { data: notifications } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', houserUserId)
    .eq('type', 'follow')
    .order('created_at', { ascending: false })
    .limit(1);

  console.log('\nNotification created:', notifications?.[0] ? '✅ YES' : '❌ NO');
  if (notifications?.[0]) {
    console.log('Title:', notifications[0].title);
    console.log('Message:', notifications[0].message);
    console.log('Created:', notifications[0].created_at);
  }
}

testFollowNotification();

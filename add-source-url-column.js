const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://pgezrygzubjieqfzyccy.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTgzMTk2NywiZXhwIjoyMDc3NDA3OTY3fQ.seH1M4i7XjDOCCKePsSXdDmnQ4SgWBAsiODJ7Oiz06g'
);

async function addColumn() {
  const { error } = await supabase.rpc('exec_sql', {
    sql: `ALTER TABLE homes ADD COLUMN IF NOT EXISTS source_url TEXT;`
  });
  
  if (error) {
    console.error('Error:', error.message);
  } else {
    console.log('✅ Added source_url column to homes table');
  }
}

addColumn();

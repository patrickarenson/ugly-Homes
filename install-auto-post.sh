#!/bin/bash

# Quick setup script for automated property posting

echo "🏠 Setting up automated property posting for Houser..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Install dependencies
echo "📦 Installing dependencies..."
npm install @supabase/supabase-js

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Get a RapidAPI key:"
echo "   • Sign up at https://rapidapi.com"
echo "   • Subscribe to 'Zillow API' (free tier available)"
echo "   • Copy your API key"
echo ""
echo "2. Test the script:"
echo "   export RAPIDAPI_KEY='your-rapidapi-key-here'"
echo "   node auto-post-properties.js"
echo ""
echo "3. Schedule it to run at 2:30 AM daily:"
echo "   • Option A (cron):"
echo "     crontab -e"
echo "     Add: 30 2 * * * export RAPIDAPI_KEY='your-key' && /usr/local/bin/node \"$PWD/auto-post-properties.js\" >> /tmp/houser-autopost.log 2>&1"
echo ""
echo "   • Option B (launchd - recommended for Mac):"
echo "     See AUTO-POST-SETUP.md for launchd setup"
echo ""
echo "📖 Full documentation: AUTO-POST-SETUP.md"

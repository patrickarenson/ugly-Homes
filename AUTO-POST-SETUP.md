# Automated Property Posting Setup

This guide shows you how to automatically post Central Florida properties every night from the "Houser" account.

## Prerequisites

1. **Node.js** - Install from [nodejs.org](https://nodejs.org)
2. **Supabase Service Role Key** - Get this from your Supabase project settings

## Quick Setup

### 1. Run the install script

```bash
cd "/Users/patrickarenson/Desktop/Ugly Homes/Ugly Homes"
./install-auto-post.sh
```

### 2. Get a RapidAPI Key

1. Sign up at [RapidAPI.com](https://rapidapi.com)
2. Subscribe to the **"Zillow API"** (free tier available)
3. Copy your API key

### 3. Test the Script

```bash
export RAPIDAPI_KEY='your-rapidapi-key-here'
node auto-post-properties.js
```

The script will:
- ✅ Fetch 15 trending Orlando properties from Zillow
- ✅ Check for duplicates
- ✅ Post from the "Houser" account
- ✅ Skip any properties already in your database

## Schedule for Nighttime (2-3 AM)

### Option A: macOS (using launchd)

1. Create a plist file:

```bash
nano ~/Library/LaunchAgents/com.houser.autopost.plist
```

2. Add this content (runs at 2:30 AM daily):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.houser.autopost</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>/Users/patrickarenson/Desktop/Ugly Homes/Ugly Homes/auto-post-properties.js</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>30</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/houser-autopost.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/houser-autopost-error.log</string>
</dict>
</plist>
```

3. Load the job:

```bash
launchctl load ~/Library/LaunchAgents/com.houser.autopost.plist
```

4. Check status:

```bash
launchctl list | grep houser
```

5. View logs:

```bash
tail -f /tmp/houser-autopost.log
```

### Option B: Cron (simpler, but requires Mac to be awake)

1. Open crontab:

```bash
crontab -e
```

2. Add this line (runs at 2:30 AM daily):

```
30 2 * * * /usr/local/bin/node "/Users/patrickarenson/Desktop/Ugly Homes/Ugly Homes/auto-post-properties.js" >> /tmp/houser-autopost.log 2>&1
```

3. Save and exit

### Option C: GitHub Actions (runs in the cloud, no Mac needed)

Create `.github/workflows/auto-post.yml`:

```yaml
name: Auto-Post Properties

on:
  schedule:
    - cron: '30 6 * * *'  # 2:30 AM EST (6:30 UTC)
  workflow_dispatch:  # Allow manual trigger

jobs:
  post-properties:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm install @supabase/supabase-js

      - name: Run auto-post script
        env:
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
        run: node auto-post-properties.js
```

Add your Supabase key as a GitHub secret named `SUPABASE_SERVICE_KEY`.

## Configuration

Current settings in `auto-post-properties.js`:

- **PROPERTIES_PER_DAY**: 15 (most popular listings daily)
- **GREATER_ORLANDO_CITIES**: Greater Orlando area only
- **HOUSER_USERNAME**: "Houser"
- **Schedule**: 2:30 AM daily (nighttime posting)

## What's Already Configured

✅ **Supabase Service Key** - Already added to the script
✅ **Trending Properties Function** - Uses RapidAPI to fetch popular Orlando listings
✅ **Duplicate Detection** - Automatically skips properties already posted
✅ **Greater Orlando Focus** - Only posts from Orlando, Winter Park, Kissimmee, etc.
✅ **15 Properties Daily** - Posts the most featured/trending listings

## What You Need

⏳ **RapidAPI Key** - Get from rapidapi.com (Zillow API subscription)
⏳ **Schedule Setup** - Configure cron or launchd to run at 2:30 AM

## Troubleshooting

**Script not running?**
- Check logs: `tail -f /tmp/houser-autopost.log`
- Verify Node path: `which node`
- Test manually: `node auto-post-properties.js`

**Mac asleep at 2 AM?**
- System Preferences → Energy Saver → Prevent automatic sleep
- OR use GitHub Actions instead (runs in cloud)

**Duplicates being posted?**
- The script automatically checks for duplicates using `source_url`
- No duplicates will be posted

## Quick Start (TL;DR)

```bash
# 1. Install dependencies
cd "/Users/patrickarenson/Desktop/Ugly Homes/Ugly Homes"
./install-auto-post.sh

# 2. Get RapidAPI key from rapidapi.com (Zillow API)

# 3. Test it
export RAPIDAPI_KEY='your-key-here'
node auto-post-properties.js

# 4. Schedule it (2:30 AM daily)
crontab -e
# Add: 30 2 * * * export RAPIDAPI_KEY='your-key' && /usr/local/bin/node "/Users/patrickarenson/Desktop/Ugly Homes/Ugly Homes/auto-post-properties.js" >> /tmp/houser-autopost.log 2>&1
```

That's it! You'll get 15 trending Orlando properties posted every night at 2:30 AM from the Houser account.

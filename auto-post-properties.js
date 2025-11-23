#!/usr/bin/env node

/**
 * Automated Property Poster for Houser
 *
 * This script automatically posts trending Central Florida properties daily.
 * - Focuses on Central Florida (Orlando, Tampa, Jacksonville metro areas)
 * - Checks for duplicates before posting
 * - Posts from the "Houser" account
 * - Can be run via cron: 0 10 * * * (daily at 10 AM)
 */

const { createClient } = require('@supabase/supabase-js');

// CONFIGURATION
const SUPABASE_URL = 'https://pgezrygzubjieqfzyccy.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBnZXpyeWd6dWJqaWVxZnp5Y2N5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTgzMTk2NywiZXhwIjoyMDc3NDA3OTY3fQ.seH1M4i7XjDOCCKePsSXdDmnQ4SgWBAsiODJ7Oiz06g';
const SCRAPING_API = 'https://api.housers.us/api/scrape-listing';
const HOUSER_USERNAME = 'houser';
const PROPERTIES_PER_DAY = 15; // Post 15 most popular listings daily
const RAPIDAPI_KEY = '70a79df3bamsh2cac396016ebdacp1ce048jsnfa758af38d6c';

// Greater Orlando Area - Primary Focus
const GREATER_ORLANDO_CITIES = [
  'Orlando',
  'Winter Park',
  'Kissimmee',
  'Altamonte Springs',
  'Oviedo',
  'Lake Mary',
  'Sanford',
  'Apopka',
  'Winter Garden',
  'Windermere',
  'Maitland',
  'Casselberry'
];

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
 * Check if a Zillow URL already exists in the database
 */
async function isDuplicate(zillowUrl) {
  const { data, error } = await supabase
    .from('homes')
    .select('id')
    .eq('source_url', zillowUrl)
    .limit(1);

  if (error) {
    console.error(`⚠️ Error checking duplicate: ${error.message}`);
    return false;
  }

  return data && data.length > 0;
}

/**
 * Scrape property details from Zillow URL
 */
async function scrapeProperty(zillowUrl) {
  console.log(`🔍 Scraping: ${zillowUrl}`);

  const response = await fetch(SCRAPING_API, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ url: zillowUrl })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Scraping failed: ${error}`);
  }

  return await response.json();
}

/**
 * Post property to Supabase
 */
async function postProperty(houserUserId, propertyData, zillowUrl) {
  console.log(`📤 Posting property: ${propertyData.address || 'Unknown'}`);

  // Map scraped data to your database schema
  const homeData = {
    user_id: houserUserId,
    title: propertyData.address || 'Central Florida Property',
    price: propertyData.price ? parseFloat(propertyData.price.replace(/[^0-9.]/g, '')) : null,
    address: propertyData.address,
    unit: propertyData.unit,
    city: propertyData.city,
    state: propertyData.state,
    zip_code: propertyData.zipCode,
    bedrooms: propertyData.bedrooms,
    bathrooms: propertyData.bathrooms,
    description: propertyData.description,
    image_urls: propertyData.images || [],
    post_type: 'listing',
    source_url: zillowUrl,

    // Additional details
    school_district: propertyData.schoolDistrict,
    elementary_school: propertyData.elementarySchool,
    middle_school: propertyData.middleSchool,
    high_school: propertyData.highSchool,
    school_rating: propertyData.schoolRating,
    hoa_fee: propertyData.hoaFee,
    lot_size_sqft: propertyData.lotSizeSqft,
    living_area_sqft: propertyData.livingAreaSqft,
    year_built: propertyData.yearBuilt,
    property_type_detail: propertyData.propertyTypeDetail,
    parking_spaces: propertyData.parkingSpaces,
    stories: propertyData.stories,
    heating_type: propertyData.heatingType,
    cooling_type: propertyData.coolingType,
    appliances_included: propertyData.appliancesIncluded,

    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  const { data, error } = await supabase
    .from('homes')
    .insert(homeData)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to post property: ${error.message}`);
  }

  console.log(`✅ Posted property ID: ${data.id}`);
  return data;
}

/**
 * Fetch trending Zillow URLs for Greater Orlando using RapidAPI
 */
async function fetchTrendingProperties() {
  console.log('🔥 Fetching 15 most popular Greater Orlando properties...');

  try {
    // Use RapidAPI's Zillow endpoint to get featured/trending listings
    const url = new URL('https://zillow-com1.p.rapidapi.com/propertyExtendedSearch');
    url.searchParams.append('location', 'Orlando, FL');
    url.searchParams.append('status_type', 'ForSale');
    url.searchParams.append('home_type', 'Houses');
    url.searchParams.append('sort', 'Featured'); // Featured = trending/popular
    url.searchParams.append('page', '1');

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'X-RapidAPI-Key': RAPIDAPI_KEY,
        'X-RapidAPI-Host': 'zillow-com1.p.rapidapi.com'
      }
    });

    if (!response.ok) {
      throw new Error(`RapidAPI request failed: ${response.status}`);
    }

    const data = await response.json();

    if (!data.props || data.props.length === 0) {
      console.log('⚠️ No properties found from API');
      return [];
    }

    // Extract Zillow URLs from the results
    const propertyUrls = data.props
      .filter(prop => prop.zpid) // Must have Zillow property ID
      .slice(0, PROPERTIES_PER_DAY) // Get exactly 15
      .map(prop => {
        // Construct Zillow URL from zpid
        const zpid = prop.zpid;
        const address = prop.address || 'property';
        const slug = address.toLowerCase().replace(/[^a-z0-9]+/g, '-');
        return `https://www.zillow.com/homedetails/${slug}/${zpid}_zpid/`;
      });

    console.log(`✅ Found ${propertyUrls.length} trending Orlando properties`);
    return propertyUrls;

  } catch (error) {
    console.error(`❌ Error fetching from RapidAPI: ${error.message}`);
    console.log('💡 Falling back to manual curated list...');

    // Fallback: Return empty array (script will skip posting)
    // You can add a manual curated list here if needed
    return [];
  }
}

/**
 * Main execution function
 */
async function main() {
  console.log('🏠 Starting automated property posting...\n');

  try {
    // 1. Get Houser user ID
    const houserUserId = await getHouserUserId();

    // 2. Fetch trending properties
    const propertyUrls = await fetchTrendingProperties();

    if (propertyUrls.length === 0) {
      console.log('\n⚠️ No properties found. Did you implement fetchTrendingProperties()?');
      console.log('\n📖 Next steps:');
      console.log('1. Add your Supabase service role key to SUPABASE_SERVICE_KEY');
      console.log('2. Implement fetchTrendingProperties() to search Zillow');
      console.log('3. Set up a cron job to run this script daily');
      return;
    }

    console.log(`\n📋 Found ${propertyUrls.length} trending properties`);

    // 3. Process properties
    let posted = 0;
    let skipped = 0;
    let failed = 0;

    for (const url of propertyUrls.slice(0, PROPERTIES_PER_DAY)) {
      try {
        // Check for duplicates
        if (await isDuplicate(url)) {
          console.log(`⏭️ Skipping duplicate: ${url}`);
          skipped++;
          continue;
        }

        // Scrape property data
        const propertyData = await scrapeProperty(url);

        // Post to database
        await postProperty(houserUserId, propertyData, url);
        posted++;

        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 2000));

      } catch (error) {
        console.error(`❌ Failed to process ${url}: ${error.message}`);
        failed++;
      }
    }

    // 4. Summary
    console.log('\n📊 Summary:');
    console.log(`✅ Posted: ${posted}`);
    console.log(`⏭️ Skipped (duplicates): ${skipped}`);
    console.log(`❌ Failed: ${failed}`);

  } catch (error) {
    console.error(`\n💥 Fatal error: ${error.message}`);
    process.exit(1);
  }
}

// Run the script
main();

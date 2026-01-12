import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, terra-signature',
}

serve(async (req) => {
  console.log('🚀 Terra webhook received!')
  
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.text()
    console.log('📦 Raw body length:', body.length)
    
    let data
    try {
      data = JSON.parse(body)
    } catch (parseError) {
      console.error('❌ JSON parse error:', parseError)
      return new Response(
        JSON.stringify({ error: 'Invalid JSON' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`📨 Webhook type: ${data.type}`)
    console.log(`👤 User reference_id: ${data.user?.reference_id}`)
    console.log(`🏢 Provider: ${data.user?.provider}`)
    
    // Create Supabase admin client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseKey) {
      console.error('❌ Missing Supabase credentials')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const supabase = createClient(supabaseUrl, supabaseKey)
    console.log('✅ Supabase client created')
    
    // Handle different webhook types
    switch (data.type) {
      case 'auth':
        console.log('🔐 Processing auth event...')
        await handleAuth(supabase, data)
        break
        
      case 'deauth':
        console.log('🔓 Processing deauth event...')
        await handleDeauth(supabase, data)
        break
        
      case 'activity':
        console.log('🏃 Processing activity event...')
        await handleActivity(supabase, data)
        break
        
      case 'body':
        console.log('📊 Body data received (not processed)')
        break
        
      case 'daily':
        console.log('📅 Daily data received (not processed)')
        break
        
      case 'sleep':
        console.log('😴 Sleep data received (not processed)')
        break
        
      default:
        console.log(`❓ Unhandled webhook type: ${data.type}`)
    }
    
    console.log('✅ Webhook processed successfully')
    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    console.error('❌ Webhook error:', error.message)
    console.error('Stack:', error.stack)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function handleAuth(supabase: any, data: any) {
  const user = data.user
  if (!user) {
    console.log('⚠️ No user in auth data')
    return
  }
  
  const { reference_id, user_id, provider } = user
  console.log(`Auth: User ${reference_id} connected ${provider} (terra_user_id: ${user_id})`)
  
  // Try to store connection - table might not exist
  try {
    const { error } = await supabase
      .from('terra_connections')
      .upsert({
        user_id: reference_id,
        terra_user_id: user_id,
        provider: provider,
        connected_at: new Date().toISOString(),
        is_active: true
      }, {
        onConflict: 'user_id,provider'
      })
    
    if (error) {
      console.error('⚠️ Error storing Terra connection:', error.message)
    } else {
      console.log('✅ Terra connection stored')
    }
  } catch (e) {
    console.error('⚠️ terra_connections table might not exist:', e.message)
  }
}

async function handleDeauth(supabase: any, data: any) {
  const user = data.user
  if (!user) return
  
  const { reference_id, provider } = user
  console.log(`Deauth: User ${reference_id} disconnected ${provider}`)
  
  try {
    const { error } = await supabase
      .from('terra_connections')
      .update({ is_active: false })
      .eq('user_id', reference_id)
      .eq('provider', provider)
    
    if (error) {
      console.error('⚠️ Error updating Terra connection:', error.message)
    }
  } catch (e) {
    console.error('⚠️ Deauth error:', e.message)
  }
}

async function handleActivity(supabase: any, data: any) {
  const user = data.user
  const activities = data.data || []
  
  if (!user) {
    console.log('⚠️ No user in activity data')
    return
  }
  
  if (activities.length === 0) {
    console.log('⚠️ No activities in payload')
    return
  }
  
  console.log(`📊 Processing ${activities.length} activities for user ${user.reference_id}`)
  
  for (const activity of activities) {
    // Log full activity structure for debugging
    console.log(`  📋 Full activity metadata:`, JSON.stringify(activity.metadata || {}))
    console.log(`  📋 Distance data:`, JSON.stringify(activity.distance_data || {}))
    console.log(`  📋 Active durations:`, JSON.stringify(activity.active_durations_data || {}))
    
    const activityType = mapActivityType(activity.metadata?.type)
    const title = getActivityTitle(activityType, activity.metadata?.name)
    
    // Get duration - try multiple fields
    const durationSeconds = activity.active_durations_data?.activity_seconds || 
                           activity.metadata?.duration_seconds ||
                           activity.duration_data?.activity_seconds ||
                           0
    
    // Get distance - try multiple fields
    const distanceMeters = activity.distance_data?.distance_meters || 
                          activity.metadata?.distance_meters ||
                          activity.summary?.distance_meters ||
                          0
    
    // Get device name from Terra data
    const deviceName = activity.metadata?.device_name || 
                       activity.device_data?.name ||
                       activity.device_data?.hardware_version ||
                       getProviderDeviceName(user.provider)
    
    // Get average power (watts) for cycling
    const avgPower = activity.power_data?.avg_watts || 
                    activity.metadata?.average_watts ||
                    null
    
    console.log(`  - Activity: ${title}, Type: ${activityType}, Duration: ${durationSeconds}s, Distance: ${distanceMeters}m, Device: ${deviceName}, Power: ${avgPower}W`)
    
    // Build description with power if available
    let description = activity.metadata?.summary || null
    if (avgPower && avgPower > 0) {
      description = description ? `${description} | Snitt ${Math.round(avgPower)}W` : `Snitt ${Math.round(avgPower)}W`
    }
    
    // Get map/route image URL (Zwift and others may provide this)
    const mapImageUrl = activity.metadata?.map_image_url ||
                       activity.metadata?.route_image ||
                       activity.metadata?.polyline_map_url ||
                       activity.map_data?.map_image_url ||
                       activity.laps?.[0]?.map_data?.map_image_url ||
                       null
    
    // Get average speed (m/s -> km/h)
    const avgSpeedMs = activity.distance_data?.detailed?.avg_velocity_meters_per_second ||
                      activity.metadata?.average_speed ||
                      0
    const avgSpeedKmh = avgSpeedMs > 0 ? (avgSpeedMs * 3.6).toFixed(1) : null
    
    // Get calories
    const calories = activity.calories_data?.total_burned_calories ||
                    activity.metadata?.calories ||
                    null
    
    console.log(`  🗺️ Map image: ${mapImageUrl}`)
    console.log(`  ⚡ Avg speed: ${avgSpeedKmh} km/h, Calories: ${calories}`)
    
    // Transform Terra activity to our workout_posts format
    // Ensure all numeric values are proper integers/floats
    const workoutPost: any = {
      user_id: user.reference_id,
      activity_type: activityType,
      title: title,
      description: description,
      duration: Math.round(durationSeconds), // Ensure integer
      distance: parseFloat((distanceMeters / 1000).toFixed(2)), // Convert to km as float
      elevation_gain: Math.round(activity.distance_data?.elevation?.gain_actual_meters || activity.metadata?.elevation_gain || 0), // Ensure integer
      source: user.provider?.toLowerCase() || 'terra',
      device_name: deviceName,
      external_id: activity.metadata?.id || `terra_${Date.now()}`,
      created_at: activity.metadata?.start_time || new Date().toISOString()
    }
    
    // Add optional fields if available
    if (mapImageUrl) {
      workoutPost.image_url = mapImageUrl
    }
    
    // Add watts info to description if available (since avg_watts column doesn't exist)
    if (avgPower && avgPower > 0 && !workoutPost.description) {
      workoutPost.description = `Snitt ${Math.round(avgPower)}W`
    } else if (avgPower && avgPower > 0 && workoutPost.description) {
      workoutPost.description = `${workoutPost.description} • Snitt ${Math.round(avgPower)}W`
    }
    
    console.log(`  📝 Workout post to insert:`, JSON.stringify(workoutPost))
    
    // Check if activity already exists
    const { data: existing, error: selectError } = await supabase
      .from('workout_posts')
      .select('id')
      .eq('external_id', workoutPost.external_id)
      .maybeSingle()
    
    if (selectError) {
      console.error('  ⚠️ Error checking existing:', selectError.message)
    }
    
    if (existing) {
      console.log(`  ⏭️ Activity already exists: ${existing.id}`)
      continue
    }
    
    const { data: inserted, error: insertError } = await supabase
      .from('workout_posts')
      .insert(workoutPost)
      .select()
    
    if (insertError) {
      console.error('  ❌ Error inserting activity:', insertError.message)
      console.error('  Details:', JSON.stringify(insertError))
    } else {
      console.log(`  ✅ Inserted activity: ${workoutPost.title}`)
    }
  }
}

function getActivityTitle(activityType: string, originalName?: string): string {
  // Map activity types to proper Swedish titles
  const titleMap: Record<string, string> = {
    'Simning': 'Simpass',
    'Löpning': 'Löppass',
    'Cykling': 'Cykelpass',
    'Gympass': 'Gympass',
    'Promenad': 'Promenad',
    'Vandring': 'Vandring',
    'Skidåkning': 'Skidpass',
    'Golf': 'Golfrunda',
    'Yoga': 'Yogapass',
    'Rodd': 'Roddpass',
    'Cardio': 'Cardiopass',
    'Träning': 'Träningspass'
  }
  
  // Use our Swedish title, or fall back to original name if we don't have a mapping
  return titleMap[activityType] || originalName || 'Träningspass'
}

function getProviderDeviceName(provider: string): string {
  const providerNames: Record<string, string> = {
    'GARMIN': 'Garmin',
    'FITBIT': 'Fitbit',
    'POLAR': 'Polar',
    'SUUNTO': 'Suunto',
    'WAHOO': 'Wahoo',
    'OURA': 'Oura Ring',
    'WHOOP': 'Whoop',
    'COROS': 'Coros',
    'APPLE': 'Apple Watch',
    'GOOGLE': 'Google Fit',
    'SAMSUNG': 'Samsung Health',
    'PELOTON': 'Peloton',
    'ZWIFT': 'Zwift'
  }
  return providerNames[provider?.toUpperCase()] || provider || 'Extern enhet'
}

function mapActivityType(terraType: any): string {
  // Handle non-string values
  if (!terraType || typeof terraType !== 'string') {
    console.log(`⚠️ terraType is not a string:`, terraType)
    return 'Träning'
  }
  
  console.log(`🏷️ Mapping activity type: ${terraType}`)
  
  const mapping: Record<string, string> = {
    'RUNNING': 'Löpning',
    'CYCLING': 'Cykling',
    'SWIMMING': 'Simning',
    'WALKING': 'Promenad',
    'HIKING': 'Vandring',
    'WORKOUT': 'Gympass',
    'STRENGTH_TRAINING': 'Gympass',
    'YOGA': 'Yoga',
    'OTHER': 'Träning',
    'SKIING': 'Skidåkning',
    'GOLF': 'Golf',
    'INDOOR_CYCLING': 'Cykling',
    'ELLIPTICAL': 'Gympass',
    'ROWING': 'Rodd',
    'WALKING_RUNNING': 'Löpning',
    'FITNESS_EQUIPMENT': 'Gympass',
    'CARDIO': 'Cardio',
    // Zwift specific
    'VIRTUAL_RIDE': 'Cykling',
    'VIRTUAL_RUN': 'Löpning',
    'VIRTUAL_CYCLING': 'Cykling',
    'VIRTUAL_RUNNING': 'Löpning',
    'RIDE': 'Cykling',
    'RUN': 'Löpning',
    'BIKING': 'Cykling',
    // Pool swimming
    'POOL_SWIMMING': 'Simning',
    'OPEN_WATER_SWIMMING': 'Simning',
    'LAP_SWIMMING': 'Simning'
  }
  
  const result = mapping[terraType.toUpperCase()] || 'Träning'
  console.log(`🏷️ Mapped to: ${result}`)
  return result
}

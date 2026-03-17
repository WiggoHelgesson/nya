import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { postId, imageUrl } = await req.json()

    if (!postId || !imageUrl) {
      return new Response(JSON.stringify({ status: 'approved' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) {
      console.error('OPENAI_API_KEY not set')
      return new Response(JSON.stringify({ status: 'approved' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Build a public URL for the image (Supabase storage paths need the full URL)
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const fullImageUrl = imageUrl.startsWith('http')
      ? imageUrl
      : `${supabaseUrl}/storage/v1/object/public/${imageUrl}`

    // Call OpenAI Vision API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 10,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Does this image appear to be taken at a gym or related to physical training or exercise? Answer only yes or no.',
              },
              {
                type: 'image_url',
                image_url: { url: fullImageUrl, detail: 'low' },
              },
            ],
          },
        ],
      }),
    })

    if (!openaiResponse.ok) {
      console.error('OpenAI error:', await openaiResponse.text())
      return new Response(JSON.stringify({ status: 'approved' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const openaiData = await openaiResponse.json()
    const answer = (openaiData.choices?.[0]?.message?.content ?? '').toLowerCase().trim()
    const isGymRelated = answer.startsWith('yes')

    console.log(`Post ${postId} - AI answer: "${answer}" - gym related: ${isGymRelated}`)

    if (!isGymRelated) {
      // Flag the post for manual review
      const supabase = createClient(
        supabaseUrl,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      )
      const { error } = await supabase
        .from('workout_posts')
        .update({ moderation_status: 'pending_review' })
        .eq('id', postId)

      if (error) {
        console.error('Failed to update moderation status:', error)
      }

      return new Response(JSON.stringify({ status: 'pending_review' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ status: 'approved' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('moderate-post error:', err)
    // Fail open — never block a post due to an error
    return new Response(JSON.stringify({ status: 'approved' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

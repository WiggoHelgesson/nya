import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SKOLVERKET_BASE = "https://api.skolverket.se/skolenhetsregistret/v2"
const BATCH_SIZE = 30

interface SchoolUnit {
  schoolUnitCode: string
  name: string
  status: string
}

interface SchoolDetail {
  data: {
    schoolUnitCode: string
    attributes: {
      displayName: string
      status: string
      schoolTypes?: string[]
      municipalityCode?: string
      addresses?: Array<{ locality?: string }>
    }
  }
}

async function fetchSchoolDetail(code: string): Promise<SchoolDetail | null> {
  try {
    const res = await fetch(`${SKOLVERKET_BASE}/school-units/${code}`, {
      headers: { "Accept": "application/json" },
    })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. Fetch all school units from Skolverket
    const listRes = await fetch(`${SKOLVERKET_BASE}/school-units`, {
      headers: { "Accept": "application/json" },
    })

    if (!listRes.ok) {
      throw new Error(`Skolverket API returned ${listRes.status}`)
    }

    const listData = await listRes.json()
    const allUnits: SchoolUnit[] = listData.data.attributes

    // 2. Filter for AKTIV schools only
    const activeUnits = allUnits.filter((u: SchoolUnit) => u.status === "AKTIV")
    console.log(`Found ${activeUnits.length} active school units out of ${allUnits.length} total`)

    // 3. Fetch details in batches to find gymnasium schools
    const gymnasiumSchools: Array<{ id: string; name: string; type: string; status: string; municipality: string | null }> = []

    for (let i = 0; i < activeUnits.length; i += BATCH_SIZE) {
      const batch = activeUnits.slice(i, i + BATCH_SIZE)
      const details = await Promise.all(
        batch.map((unit: SchoolUnit) => fetchSchoolDetail(unit.schoolUnitCode))
      )

      for (const detail of details) {
        if (!detail) continue
        const attrs = detail.data.attributes
        const types = attrs.schoolTypes || []

        if (types.includes("GY")) {
          const locality = attrs.addresses?.find(a => a.locality)?.locality || null
          gymnasiumSchools.push({
            id: detail.data.schoolUnitCode,
            name: attrs.displayName || attrs.status,
            type: "gymnasium",
            status: "AKTIV",
            municipality: locality,
          })
        }
      }

      // Brief pause between batches to avoid rate limiting
      if (i + BATCH_SIZE < activeUnits.length) {
        await new Promise(resolve => setTimeout(resolve, 200))
      }
    }

    console.log(`Found ${gymnasiumSchools.length} gymnasium schools`)

    // 4. Upsert into the schools table (only gymnasium; universities are seeded via SQL)
    if (gymnasiumSchools.length > 0) {
      // Upsert in chunks of 500
      for (let i = 0; i < gymnasiumSchools.length; i += 500) {
        const chunk = gymnasiumSchools.slice(i, i + 500)
        const { error } = await supabase
          .from("schools")
          .upsert(chunk, { onConflict: "id" })

        if (error) {
          console.error(`Upsert error at chunk ${i}:`, error)
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        total_active: activeUnits.length,
        gymnasium_count: gymnasiumSchools.length,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error) {
    console.error("Error:", error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    )
  }
})

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

/**
 * Find or create a direct_conversations row for buyer + seller + listing.
 * Mirrors accept-marketplace-offer / book-marketplace-shipping behaviour.
 */
export async function resolveListingConversation(
  supabaseAdmin: SupabaseClient,
  buyerId: string,
  sellerId: string,
  listingId: string
): Promise<string | null> {
  try {
    const { data: existingId } = await supabaseAdmin.rpc('find_direct_conversation', {
      p_user1: buyerId,
      p_user2: sellerId,
      p_listing: listingId,
    })

    if (existingId && typeof existingId === 'string' && existingId.length > 0) {
      return existingId
    }

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('direct_conversations')
      .insert({
        created_by: sellerId,
        listing_id: listingId,
      })
      .select('id')
      .single()

    if (insertError || !inserted) {
      console.error('resolveListingConversation: failed to create conversation', insertError)
      return null
    }

    await supabaseAdmin.from('direct_conversation_participants').insert([
      { conversation_id: inserted.id, user_id: buyerId },
      { conversation_id: inserted.id, user_id: sellerId },
    ])

    return inserted.id as string
  } catch (e) {
    console.error('resolveListingConversation error:', e)
    return null
  }
}

export async function fetchBuyerDisplayName(
  supabaseAdmin: SupabaseClient,
  buyerId: string
): Promise<string> {
  const { data } = await supabaseAdmin
    .from('profiles')
    .select('username')
    .eq('id', buyerId)
    .maybeSingle()
  const u = data?.username
  return typeof u === 'string' && u.trim().length > 0 ? u.trim() : 'Någon'
}

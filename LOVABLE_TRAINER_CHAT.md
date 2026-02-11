# Lovable: Real-Time Trainer Chat System

## Overview
The iOS app now has a chat feature where app users can send messages to trainers. Trainers need to see and respond to these messages in **real-time** on the coach web app (upanddowncoach.com). This is the highest priority feature for the web app.

## Database Tables (Already Created)

### `trainer_conversations`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Conversation ID |
| trainer_id | UUID (FK → trainer_profiles) | The trainer in this conversation |
| user_id | UUID (FK → auth.users) | The app user in this conversation |
| last_message_at | TIMESTAMPTZ | Timestamp of last message (auto-updated by trigger) |
| created_at | TIMESTAMPTZ | When conversation was started |

**Unique constraint**: One conversation per `(trainer_id, user_id)` pair.

### `trainer_chat_messages`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Message ID |
| conversation_id | UUID (FK → trainer_conversations) | Which conversation |
| sender_id | UUID (FK → auth.users) | Who sent it |
| message | TEXT | The message content |
| is_read | BOOLEAN | Whether recipient has read it (default: false) |
| created_at | TIMESTAMPTZ | When message was sent |

### `trainer_conversations_with_info` (View)
A convenient view that joins conversation data with trainer and user info. Returns:
- All conversation columns
- `trainer_name`, `trainer_avatar_url`, `trainer_user_id`
- `user_username`, `user_avatar_url`
- `last_message` (most recent message text)
- `unread_count` (unread messages for the current user)

**Realtime is enabled** on `trainer_chat_messages` via `supabase_realtime` publication.

## What Lovable Needs to Build

### 1. Conversations List Page (`/messages` or `/chat`)

This is the main inbox for the trainer. Show a list of all conversations.

**Fetch conversations:**
```typescript
const { data: conversations, error } = await supabase
  .from('trainer_conversations_with_info')
  .select('*')
  .order('last_message_at', { ascending: false });
```

**Each conversation card should show:**
- User's avatar (`user_avatar_url`) and username (`user_username`)
- Last message preview (`last_message`) - truncated to ~50 chars
- Time since last message (`last_message_at`) - e.g., "2 min sedan", "Igår"
- Unread badge/count (`unread_count`) - red dot or number if > 0

**Design:**
- Clean list layout, similar to WhatsApp/iMessage inbox
- Unread conversations should be **bold** / have a colored indicator
- Click opens the conversation detail

### 2. Conversation Detail Page (`/chat/:conversationId`)

The actual chat view where the trainer reads and sends messages.

**Fetch messages:**
```typescript
const { data: messages, error } = await supabase
  .from('trainer_chat_messages')
  .select('*')
  .eq('conversation_id', conversationId)
  .order('created_at', { ascending: true });
```

**Real-time subscription (CRITICAL - this must work):**
```typescript
// Subscribe to new messages in this conversation
const channel = supabase
  .channel(`chat:${conversationId}`)
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'trainer_chat_messages',
      filter: `conversation_id=eq.${conversationId}`,
    },
    (payload) => {
      // Add the new message to the messages array
      const newMessage = payload.new as TrainerChatMessage;
      setMessages(prev => [...prev, newMessage]);
      
      // Auto-scroll to bottom
      scrollToBottom();
      
      // Mark as read if not from us
      if (newMessage.sender_id !== currentUserId) {
        markAsRead(conversationId);
      }
    }
  )
  .subscribe();

// IMPORTANT: Unsubscribe when leaving the page
return () => {
  supabase.removeChannel(channel);
};
```

**Send message:**
```typescript
const sendMessage = async (message: string) => {
  const { data: { user } } = await supabase.auth.getUser();
  
  const { error } = await supabase
    .from('trainer_chat_messages')
    .insert({
      conversation_id: conversationId,
      sender_id: user.id,
      message: message.trim(),
    });
    
  if (error) {
    console.error('Failed to send message:', error);
    // Show error toast
  }
};
```

**Mark messages as read:**
```typescript
const markAsRead = async (conversationId: string) => {
  const { data: { user } } = await supabase.auth.getUser();
  
  await supabase
    .from('trainer_chat_messages')
    .update({ is_read: true })
    .eq('conversation_id', conversationId)
    .neq('sender_id', user.id)
    .eq('is_read', false);
};
```

**Chat UI design:**
- Messages from the trainer (current user) on the **right** side with a dark/primary background
- Messages from the app user on the **left** side with a light/gray background
- Show timestamp below each message (e.g., "14:32" or "Igår 18:45")
- Show user avatar next to their messages
- Text input at the bottom with send button
- Auto-scroll to the newest message
- Show "Skriv ett meddelande..." placeholder in the input

### 3. Unread Badge in Navigation

Show a badge/dot on the "Meddelanden" nav item when there are unread messages.

```typescript
// Poll for unread count or use realtime
const { data, error } = await supabase
  .from('trainer_conversations_with_info')
  .select('unread_count');

const totalUnread = data?.reduce((sum, conv) => sum + (conv.unread_count || 0), 0) || 0;
```

### 4. Real-time Subscription for Inbox

Also subscribe to changes on the conversations list so new conversations and message updates appear in real-time:

```typescript
const channel = supabase
  .channel('trainer-inbox')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'trainer_chat_messages',
    },
    () => {
      // Refetch conversations list to update last_message, unread_count, etc.
      fetchConversations();
    }
  )
  .subscribe();
```

## TypeScript Types

```typescript
interface TrainerConversation {
  id: string;
  trainer_id: string;
  user_id: string;
  last_message_at: string;
  created_at: string;
  trainer_name: string;
  trainer_avatar_url: string | null;
  trainer_user_id: string;
  user_username: string;
  user_avatar_url: string | null;
  last_message: string | null;
  unread_count: number;
}

interface TrainerChatMessage {
  id: string;
  conversation_id: string;
  sender_id: string;
  message: string;
  is_read: boolean;
  created_at: string;
}
```

## 5. Push Notifications for Chat Messages (IMPORTANT)

When a trainer sends a message from the web app, the iOS app user MUST receive a real iOS push notification. This is handled by calling the `notify-chat-message` Edge Function after inserting the message.

**After sending a message, call the Edge Function:**
```typescript
const sendMessageWithNotification = async (conversationId: string, message: string) => {
  const { data: { user } } = await supabase.auth.getUser();
  
  // 1. Insert the message
  const { error } = await supabase
    .from('trainer_chat_messages')
    .insert({
      conversation_id: conversationId,
      sender_id: user.id,
      message: message.trim(),
    });
    
  if (error) {
    console.error('Failed to send message:', error);
    return;
  }
  
  // 2. Send push notification to the recipient
  try {
    await supabase.functions.invoke('notify-chat-message', {
      body: {
        conversation_id: conversationId,
        sender_id: user.id,
        message: message.trim(),
      }
    });
    console.log('Push notification sent!');
  } catch (e) {
    console.error('Failed to send push notification:', e);
    // Don't block the UI - message was already sent
  }
};
```

**The Edge Function automatically:**
- Looks up the conversation to find sender and recipient
- Determines the sender's name and avatar from `trainer_profiles` or `profiles`
- Finds the recipient's device tokens from `device_tokens`
- Sends a real iOS push notification via APNs

**Push notification payload:**
- **Title:** Sender's name (e.g., "Josefine")
- **Body:** The message text (truncated to 100 chars)
- **Data:** `{ type: "trainer_chat_message", conversation_id: "...", sender_id: "..." }`

## 6. Push Notifications for Coach Invitations

When a trainer sends a coaching invitation from the web app, call the `send-coach-invitation` Edge Function:

```typescript
const sendCoachInvitation = async (invitationId: string, coachId: string, clientId: string, coachName: string, coachAvatarUrl?: string) => {
  await supabase.functions.invoke('send-coach-invitation', {
    body: {
      invitation_id: invitationId,
      coach_id: coachId,
      client_id: clientId,
      coach_name: coachName,
      coach_avatar_url: coachAvatarUrl,
    }
  });
};
```

This sends a push notification saying `"Coach-inbjudan: {coachName} vill coacha dig!"` and creates an in-app notification record.

## ⚠️ CRITICAL: Do NOT deploy/overwrite these Edge Functions

The following Edge Functions contain iOS APNs push notification fixes that are specific to the iOS app deployment. **DO NOT redeploy or overwrite these functions from the Lovable codebase:**

- `send-push-notification`
- `send-coach-invitation`
- `notify-chat-message`

**Why?** These functions read APNs secrets (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_P8_KEY`) inside the request handler (not at module level). This is required for Supabase Edge Runtime cold starts. If you deploy an older version that reads these at module level, push notifications will fail with "Missing APNs configuration".

**If you MUST deploy these functions**, make sure `Deno.env.get('APNS_KEY_ID')` etc. are called INSIDE the `serve()` handler or inside `createJWT()`, NOT at the top of the file.

## Important Notes

1. **Real-time is essential** - The trainer MUST see new messages instantly without refreshing. Use Supabase Realtime channels as shown above.
2. **The trainer is identified by their `user_id` in the `trainer_profiles` table** - When the trainer logs into the web app, their auth user ID matches `trainer_profiles.user_id`. Use this to find their conversations.
3. **RLS policies are set** - The database policies ensure trainers only see conversations where they are the trainer, and app users only see their own conversations.
4. **Messages table has realtime enabled** - `trainer_chat_messages` is added to the `supabase_realtime` publication.
5. **The `last_message_at` on conversations is auto-updated** by a database trigger whenever a new message is inserted.
6. **ALWAYS call `notify-chat-message` after sending a message** - This is how iOS push notifications are triggered. Without this call, the app user won't get a notification when the app is closed.
7. **ALWAYS call `send-coach-invitation` when sending an invitation** - This triggers the iOS push notification for coach invitations. Do NOT call `send-push-notification` for invitations — use `send-coach-invitation` instead.
8. **Trainer identification for conversations:**
   ```typescript
   // Get the trainer's profile to find their trainer_id
   const { data: trainerProfile } = await supabase
     .from('trainer_profiles')
     .select('id')
     .eq('user_id', currentUser.id)
     .single();
   ```

## Navigation Structure
Add "Meddelanden" as a main navigation item in the coach web app sidebar/header. It should be prominent since this is how trainers communicate with potential clients.

## Design Guidelines
- Use the same design language as the rest of upanddowncoach.com
- Keep it clean and minimal - similar to modern messaging apps
- Dark/primary color for sent messages, light gray for received
- Responsive design - works on both desktop and mobile browsers
- Show loading skeleton while messages are being fetched
- Show typing indicator placeholder (optional, future enhancement)

-- Add missing message_type column for chat messages.
-- Run this in Supabase SQL Editor.

begin;

alter table public.direct_messages
  add column if not exists message_type text not null default 'text';

alter table public.direct_messages
  drop constraint if exists direct_messages_message_type_check;

alter table public.direct_messages
  add constraint direct_messages_message_type_check
  check (message_type in ('text', 'image'));

create index if not exists idx_direct_messages_conversation_type_created
  on public.direct_messages(conversation_id, message_type, created_at desc);

commit;
